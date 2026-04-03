/// Base MCP Server implementation
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

import 'package:mcp_server_dart/src/protocol/types.dart';
import 'http_handlers.dart';
import 'middleware.dart';
import 'session_manager.dart';
import 'server_utils.dart';

// Re-export for generated code
export 'package:mcp_server_dart/src/protocol/types.dart'
    show MCPResourceContent;

/// Type definitions for handlers
typedef MCPToolHandler = Future<Object?> Function(MCPToolContext context);
typedef MCPResourceHandler = Future<MCPResourceContent> Function(String uri);
typedef MCPPromptHandler = String Function(Map<String, Object?> args);

/// Base class for MCP servers with annotation support
abstract class MCPServer {
  final Logger _logger = Logger('MCPServer');

  /// Registered tools
  final Map<String, MCPToolDefinition> _tools = {};
  final Map<String, MCPToolHandler> _toolHandlers = {};

  /// Registered resources
  final Map<String, MCPResourceDefinition> _resources = {};
  final Map<String, MCPResourceHandler> _resourceHandlers = {};

  /// Registered prompts
  final Map<String, MCPPromptDefinition> _prompts = {};
  final Map<String, MCPPromptHandler> _promptHandlers = {};

  /// Server info
  final String name;
  final String version;
  final String? description;
  final String protocolVersion;

  /// Allowed origins for CORS validation
  final List<String> allowedOrigins;

  /// Whether to validate origins (set to false to disable origin checking)
  final bool validateOrigins;

  /// Whether to allow localhost origins by default (can be disabled for strict production)
  final bool allowLocalhost;

  /// Headers that are allowed to be forwarded to MCP handlers
  /// If null, uses default safe headers (authorization, x-request-id, etc.)
  final Set<String> allowedHeaders;

  /// Authentication settings
  final bool _authEnabled;
  final TokenValidator _tokenValidator;

  /// Connection tracking for health monitoring
  final Set<RelicWebSocket> _activeConnections = <RelicWebSocket>{};
  RelicServer? _server;
  Timer? _connectionMonitor;
  late final DateTime _startTime;

  /// Session manager
  late final SessionManager _sessionManager;

  /// HTTP handlers
  late final HttpHandlers _httpHandlers;

  MCPServer({
    required this.name,
    this.version = '1.0.0',
    this.protocolVersion = '2025-11-25',
    this.description,
    this.allowedOrigins = const [],
    this.validateOrigins = false,
    this.allowLocalhost = true,
    this.allowedHeaders = const {},
    bool enableAuth = false,
    TokenValidator? tokenValidator,
  }) : _authEnabled = enableAuth,
       _tokenValidator = tokenValidator ?? defaultTokenValidator {
    _sessionManager = SessionManager();
    _startTime = DateTime.now();
    _httpHandlers = HttpHandlers(
      serverName: name,
      serverVersion: version,
      serverProtocolVersion: protocolVersion,
      serverDescription: description,
      startTime: _startTime,
      validateOrigins: validateOrigins,
      allowLocalhost: allowLocalhost,
      allowedOrigins: allowedOrigins,
      allowedHeaders: allowedHeaders,
      tools: _tools,
      resources: _resources,
      prompts: _prompts,
      activeConnections: _activeConnections,
      handleRequest: handleRequest,
      sessionManager: _sessionManager,
      authEnabled: _authEnabled,
      validateToken: _tokenValidator,
    );
  }

  /// Register a tool manually (used by generated code)
  void registerTool(
    String name,
    MCPToolHandler handler, {
    String description = '',
    String? title,
    Map<String, Object?>? inputSchema,
    MCPToolAnnotations? annotations,
    List<MCPIcon>? icons,
  }) {
    _tools[name] = MCPToolDefinition(
      name: name,
      description: description,
      title: title,
      inputSchema: inputSchema,
      annotations: annotations,
      icons: icons,
    );
    _toolHandlers[name] = handler;
    _logger.info('Registered tool: $name');
  }

  /// Register a resource manually (used by generated code)
  void registerResource(
    String name,
    MCPResourceHandler handler, {
    String description = '',
    String? title,
    String? mimeType,
    List<MCPIcon>? icons,
  }) {
    final uri = 'mcp://$name';
    _resources[uri] = MCPResourceDefinition(
      uri: uri,
      name: name,
      description: description,
      title: title,
      mimeType: mimeType,
      icons: icons,
    );
    _resourceHandlers[uri] = handler;
    _logger.info('Registered resource: $name');
  }

  /// Register a prompt manually (used by generated code)
  void registerPrompt(
    String name,
    MCPPromptHandler handler, {
    String description = '',
    String? title,
    List<MCPPromptArgument>? arguments,
    List<MCPIcon>? icons,
  }) {
    _prompts[name] = MCPPromptDefinition(
      name: name,
      description: description,
      title: title,
      arguments: arguments,
      icons: icons,
    );
    _promptHandlers[name] = handler;
    _logger.info('Registered prompt: $name');
  }

  /// Handle incoming MCP requests
  Future<MCPResponse> handleRequest(MCPRequest request) async {
    try {
      return switch (request.method) {
        'initialize' => _handleInitialize(request),
        'tools/list' => _handleToolsList(request),
        'tools/call' => await _handleToolCall(request),
        'resources/list' => _handleResourcesList(request),
        'resources/read' => await _handleResourceRead(request),
        'prompts/list' => _handlePromptsList(request),
        'prompts/get' => _handlePromptGet(request),
        'ping' => _handlePing(request),
        _ => _errorResponse(
          request.id,
          -32601,
          'Method not found: ${request.method}',
        ),
      };
    } catch (e, stackTrace) {
      _logger.severe('Error handling request: $e', e, stackTrace);
      return _internalError(request.id, e);
    }
  }

  /// Create success response
  MCPResponse _successResponse(Object? id, Map<String, dynamic> result) {
    return MCPResponse(id: id, result: result);
  }

  /// Create error response
  MCPResponse _errorResponse(Object? id, int code, String message) {
    return MCPResponse(
      id: id,
      error: MCPError(code: code, message: message),
    );
  }

  /// Create internal error response
  MCPResponse _internalError(Object? id, Object error) {
    return _errorResponse(id, -32603, 'Internal error: $error');
  }

  /// Create missing parameters error
  MCPResponse _missingParamsError(Object? id) {
    return _errorResponse(id, -32602, 'Missing parameters');
  }

  /// Require parameters from request
  Map<String, dynamic>? _requireParams(MCPRequest request) {
    return request.params;
  }

  /// Require string parameter from params
  String? _requireStringParam(Map<String, dynamic> params, String key) {
    return params[key] as String?;
  }

  /// Handle initialize request
  MCPResponse _handleInitialize(MCPRequest request) {
    return _successResponse(request.id, {
      'protocolVersion': protocolVersion,
      'capabilities': {
        'tools': {'listChanged': false},
        'resources': {'subscribe': false, 'listChanged': false},
        'prompts': {'listChanged': false},
      },
      'serverInfo': {
        'name': name,
        'version': version,
        if (description != null) 'description': description,
      },
    });
  }

  /// Handle ping request for health checking
  MCPResponse _handlePing(MCPRequest request) {
    return _successResponse(request.id, {
      'status': 'ok',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Handle tools/list request
  MCPResponse _handleToolsList(MCPRequest request) {
    return _successResponse(request.id, {
      'tools': _tools.values.map((tool) => tool.toJson()).toList(),
    });
  }

  /// Handle tools/call request
  Future<MCPResponse> _handleToolCall(MCPRequest request) async {
    final params = _requireParams(request);
    if (params == null) {
      return _missingParamsError(request.id);
    }

    final toolName = _requireStringParam(params, 'name');
    if (toolName == null) {
      return _errorResponse(request.id, -32602, 'Missing tool name');
    }

    final handler = _toolHandlers[toolName];
    if (handler == null) {
      return _errorResponse(request.id, -32601, 'Tool not found: $toolName');
    }

    try {
      final rawArguments = params['arguments'];
      final arguments = rawArguments is Map
          ? Map<String, Object?>.from(rawArguments)
          : <String, Object?>{};
      final context = MCPToolContext(
        arguments,
        toolName,
        request.id,
        headers: request.headers,
      );
      final result = await handler(context);

      if (result is MCPToolResult) {
        return _successResponse(request.id, {
          'content': _resultToContent(result.content),
          if (result.structuredContent != null)
            'structuredContent': result.structuredContent,
          if (result.resourceLinks != null)
            'resourceLinks': result.resourceLinks!
                .map((link) => link.toJson())
                .toList(),
          if (result.isError) 'isError': true,
        });
      }

      // Convert result to MCP content blocks
      final content = _resultToContent(result);

      return _successResponse(request.id, {
        'content': content,
      });
    } catch (e) {
      return _errorResponse(request.id, -32603, 'Tool execution error: $e');
    }
  }

  /// Convert a tool result to MCP content blocks.
  /// Supports MCPContent, List<MCPContent>, or falls back to JSON text encoding.
  List<Map<String, dynamic>> _resultToContent(Object? result) {
    // Handle List<MCPContent> - multiple content blocks (e.g., text + image)
    if (result is List<MCPContent>) {
      return result.map((c) => c.toJson()).toList();
    }

    // Handle single MCPContent
    if (result is MCPContent) {
      return [result.toJson()];
    }

    // Fallback: encode as JSON text (original behavior)
    return [
      {'type': 'text', 'text': jsonEncode(result)},
    ];
  }

  /// Handle resources/list request
  MCPResponse _handleResourcesList(MCPRequest request) {
    return _successResponse(request.id, {
      'resources': _resources.values
          .map((resource) => resource.toJson())
          .toList(),
    });
  }

  /// Handle resources/read request
  Future<MCPResponse> _handleResourceRead(MCPRequest request) async {
    final params = _requireParams(request);
    if (params == null) {
      return _missingParamsError(request.id);
    }

    final uri = _requireStringParam(params, 'uri');
    if (uri == null) {
      return _errorResponse(request.id, -32602, 'Missing resource URI');
    }

    final handler = _resourceHandlers[uri];
    if (handler == null) {
      return _errorResponse(request.id, -32601, 'Resource not found: $uri');
    }

    try {
      final content = await handler(uri);
      return _successResponse(request.id, {
        'contents': [content.toJson()],
      });
    } catch (e) {
      return _errorResponse(request.id, -32603, 'Resource read error: $e');
    }
  }

  /// Handle prompts/list request
  MCPResponse _handlePromptsList(MCPRequest request) {
    return _successResponse(request.id, {
      'prompts': _prompts.values.map((prompt) => prompt.toJson()).toList(),
    });
  }

  /// Handle prompts/get request
  MCPResponse _handlePromptGet(MCPRequest request) {
    final params = _requireParams(request);
    if (params == null) {
      return _missingParamsError(request.id);
    }

    final promptName = _requireStringParam(params, 'name');
    if (promptName == null) {
      return _errorResponse(request.id, -32602, 'Missing prompt name');
    }

    final handler = _promptHandlers[promptName];
    if (handler == null) {
      return _errorResponse(
        request.id,
        -32601,
        'Prompt not found: $promptName',
      );
    }

    try {
      final rawArguments = params['arguments'];
      final arguments = rawArguments is Map
          ? Map<String, Object?>.from(rawArguments)
          : <String, Object?>{};
      final result = handler(arguments);

      return _successResponse(request.id, {
        'description': _prompts[promptName]?.description ?? '',
        'messages': [
          {
            'role': 'user',
            'content': {'type': 'text', 'text': result},
          },
        ],
      });
    } catch (e) {
      return _errorResponse(request.id, -32603, 'Prompt execution error: $e');
    }
  }

  /// Start production-ready HTTP server with WebSocket support using Relic
  Future<void> serve({
    int port = 8080,
    InternetAddress? address,
    bool enableCors = true,
    Duration keepAliveTimeout = const Duration(seconds: 30),
  }) async {
    address ??= InternetAddress.loopbackIPv4;

    _logger.info('Starting MCP Server on ${address.address}:$port');
    print('🔥 Starting MCP Server on ${address.address}:$port');

    try {
      // Setup router with health check, status, and MCP endpoints
      final router = RelicApp()
        ..get('/health', _httpHandlers.healthCheckHandler)
        ..get('/status', _httpHandlers.statusHandler)
        ..use('/*', corsMiddleware(enableCors))
        ..use('/*', errorHandlingMiddleware(_logger))
        ..get('/ws', _httpHandlers.webSocketUpgradeHandler)
        ..get('/mcp', _httpHandlers.mcpSseHandler)
        ..get('/sse', _httpHandlers.mcpSseHandler)
        ..post('/mcp', _httpHandlers.mcpPostHandler)
        ..fallback = (request) => Response.notFound(
          body: Body.fromString('MCP Server - Endpoint not found'),
        );

      await router.serve(address: address, port: port);

      _logger.info('✓ MCP Server listening on ws://localhost:$port/ws');
      _logger.info('✓ Health check available at http://localhost:$port/health');

      // Setup graceful shutdown handling
      ServerUtils.setupSignalHandlers(shutdown);

      // Start connection monitoring
      _startConnectionMonitoring(keepAliveTimeout);
    } catch (e, stackTrace) {
      _logger.severe('Failed to start server: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Start connection monitoring and cleanup
  void _startConnectionMonitoring(Duration keepAliveTimeout) {
    _connectionMonitor = Timer.periodic(keepAliveTimeout, (timer) {
      _cleanupStaleConnections();
      _sessionManager.cleanupExpiredSessions();
    });
  }

  /// Clean up stale connections
  void _cleanupStaleConnections() {
    final staleConnections = _activeConnections
        .where((connection) => connection.isClosed)
        .toList();

    for (final connection in staleConnections) {
      _activeConnections.remove(connection);
    }

    if (staleConnections.isNotEmpty) {
      _logger.info('Cleaned up ${staleConnections.length} stale connections');
    }
  }

  /// Graceful shutdown
  Future<void> shutdown() async {
    _logger.info('Shutting down MCP Server...');

    // Cancel connection monitoring
    _connectionMonitor?.cancel();

    // Close all active WebSocket connections
    final futures = <Future>[];
    for (final connection in _activeConnections) {
      futures.add(connection.close());
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures, eagerError: false);
      _logger.info('Closed ${futures.length} WebSocket connections');
    }

    // Close all SSE sessions
    await _sessionManager.closeAllSessions();

    if (_server != null) {
      await _server!.close();
      _logger.info('Relic server closed');
    }

    _logger.info('✓ MCP Server shutdown complete');
  }

  /// Start the MCP server on stdio (for CLI usage)

  Future<void> stdio() => start();

  /// Start the MCP server on stdio (for CLI usage)
  Future<void> start() async {
    _logger.info('Starting MCP server on stdio');

    await for (final line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      try {
        final data = jsonDecode(line);
        final request = MCPRequest.fromJson(data);
        final response = await handleRequest(request);
        print(jsonEncode(response.toJson()));
      } catch (e) {
        _logger.severe('Error processing stdin message: $e');
        final errorResponse = MCPResponse(
          error: MCPError(code: -32700, message: 'Parse error: $e'),
        );
        print(jsonEncode(errorResponse.toJson()));
      }
    }
  }
}
