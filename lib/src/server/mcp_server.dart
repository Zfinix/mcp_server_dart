/// Base MCP Server implementation
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:logging/logging.dart';
import 'package:relic/io_adapter.dart' as io_adapter;
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
typedef MCPToolHandler = Future<dynamic> Function(MCPToolContext context);
typedef MCPResourceHandler = Future<MCPResourceContent> Function(String uri);
typedef MCPPromptHandler = String Function(Map<String, dynamic> args);

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

  /// Allowed origins for CORS validation
  final List<String> allowedOrigins;

  /// Whether to validate origins (set to false to disable origin checking)
  final bool validateOrigins;

  /// Whether to allow localhost origins by default (can be disabled for strict production)
  final bool allowLocalhost;

  /// Connection tracking for health monitoring
  final Set<WebSocket> _activeConnections = <WebSocket>{};
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
    this.description,
    this.allowedOrigins = const [],
    this.validateOrigins = false,
    this.allowLocalhost = true,
  }) {
    _sessionManager = SessionManager();
    _startTime = DateTime.now();
    _httpHandlers = HttpHandlers(
      serverName: name,
      serverVersion: version,
      serverDescription: description,
      startTime: _startTime,
      validateOrigins: validateOrigins,
      allowLocalhost: allowLocalhost,
      allowedOrigins: allowedOrigins,
      tools: _tools,
      resources: _resources,
      prompts: _prompts,
      activeConnections: _activeConnections,
      handleRequest: handleRequest,
      sessionManager: _sessionManager,
    );

    // Try to automatically call registerGeneratedHandlers if it exists
    _autoRegisterIfExists();
  }

  /// Automatically register generated handlers if the method exists
  void _autoRegisterIfExists() {
    try {
      // Use reflection to check if registerGeneratedHandlers method exists
      final instanceMirror = reflect(this);
      final classMirror = instanceMirror.type;

      // Look for the registerGeneratedHandlers method
      final methodSymbol = Symbol('registerGeneratedHandlers');

      if (classMirror.instanceMembers.containsKey(methodSymbol)) {
        instanceMirror.invoke(methodSymbol, []);
        _logger.info('✓ Automatically registered generated MCP handlers');
      } else {
        _logger.fine(
          'No generated handlers to auto-register (this is normal for manual servers)',
        );
      }
    } catch (e) {
      // Some error occurred - might be method doesn't exist or reflection failed
      _logger.fine('No generated handlers to auto-register: $e');
    }
  }

  /// Register a tool manually (used by generated code)
  void registerTool(
    String name,
    MCPToolHandler handler, {
    String description = '',
    Map<String, dynamic>? inputSchema,
  }) {
    _tools[name] = MCPToolDefinition(
      name: name,
      description: description,
      inputSchema: inputSchema,
    );
    _toolHandlers[name] = handler;
    _logger.info('Registered tool: $name');
  }

  /// Register a resource manually (used by generated code)
  void registerResource(
    String name,
    MCPResourceHandler handler, {
    String description = '',
    String? mimeType,
  }) {
    final uri = 'mcp://$name';
    _resources[uri] = MCPResourceDefinition(
      uri: uri,
      name: name,
      description: description,
      mimeType: mimeType,
    );
    _resourceHandlers[uri] = handler;
    _logger.info('Registered resource: $name');
  }

  /// Register a prompt manually (used by generated code)
  void registerPrompt(
    String name,
    MCPPromptHandler handler, {
    String description = '',
    List<MCPPromptArgument>? arguments,
  }) {
    _prompts[name] = MCPPromptDefinition(
      name: name,
      description: description,
      arguments: arguments,
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
        _ => MCPResponse(
          id: request.id,
          error: MCPError(
            code: -32601,
            message: 'Method not found: ${request.method}',
          ),
        ),
      };
    } catch (e, stackTrace) {
      _logger.severe('Error handling request: $e', e, stackTrace);
      return MCPResponse(
        id: request.id,
        error: MCPError(code: -32603, message: 'Internal error: $e'),
      );
    }
  }

  /// Handle initialize request
  MCPResponse _handleInitialize(MCPRequest request) {
    return MCPResponse(
      id: request.id,
      result: {
        'protocolVersion': '2025-06-18',
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
      },
    );
  }

  /// Handle ping request for health checking
  MCPResponse _handlePing(MCPRequest request) {
    return MCPResponse(
      id: request.id,
      result: {'status': 'ok', 'timestamp': DateTime.now().toIso8601String()},
    );
  }

  /// Handle tools/list request
  MCPResponse _handleToolsList(MCPRequest request) {
    return MCPResponse(
      id: request.id,
      result: {'tools': _tools.values.map((tool) => tool.toJson()).toList()},
    );
  }

  /// Handle tools/call request
  Future<MCPResponse> _handleToolCall(MCPRequest request) async {
    final params = request.params;
    if (params == null) {
      return MCPResponse(
        id: request.id,
        error: MCPError(code: -32602, message: 'Missing parameters'),
      );
    }

    final toolName = params['name'] as String?;
    if (toolName == null) {
      return MCPResponse(
        id: request.id,
        error: MCPError(code: -32602, message: 'Missing tool name'),
      );
    }

    final handler = _toolHandlers[toolName];
    if (handler == null) {
      return MCPResponse(
        id: request.id,
        error: MCPError(code: -32601, message: 'Tool not found: $toolName'),
      );
    }

    try {
      final arguments = params['arguments'] as Map<String, dynamic>? ?? {};
      final context = MCPToolContext(arguments, toolName, request.id);
      final result = await handler(context);

      return MCPResponse(
        id: request.id,
        result: {
          'content': [
            {'type': 'text', 'text': jsonEncode(result)},
          ],
        },
      );
    } catch (e) {
      return MCPResponse(
        id: request.id,
        error: MCPError(code: -32603, message: 'Tool execution error: $e'),
      );
    }
  }

  /// Handle resources/list request
  MCPResponse _handleResourcesList(MCPRequest request) {
    return MCPResponse(
      id: request.id,
      result: {
        'resources': _resources.values
            .map((resource) => resource.toJson())
            .toList(),
      },
    );
  }

  /// Handle resources/read request
  Future<MCPResponse> _handleResourceRead(MCPRequest request) async {
    final params = request.params;
    if (params == null) {
      return MCPResponse(
        id: request.id,
        error: MCPError(code: -32602, message: 'Missing parameters'),
      );
    }

    final uri = params['uri'] as String?;
    if (uri == null) {
      return MCPResponse(
        id: request.id,
        error: MCPError(code: -32602, message: 'Missing resource URI'),
      );
    }

    final handler = _resourceHandlers[uri];
    if (handler == null) {
      return MCPResponse(
        id: request.id,
        error: MCPError(code: -32601, message: 'Resource not found: $uri'),
      );
    }

    try {
      final content = await handler(uri);
      return MCPResponse(
        id: request.id,
        result: {
          'contents': [content.toJson()],
        },
      );
    } catch (e) {
      return MCPResponse(
        id: request.id,
        error: MCPError(code: -32603, message: 'Resource read error: $e'),
      );
    }
  }

  /// Handle prompts/list request
  MCPResponse _handlePromptsList(MCPRequest request) {
    return MCPResponse(
      id: request.id,
      result: {
        'prompts': _prompts.values.map((prompt) => prompt.toJson()).toList(),
      },
    );
  }

  /// Handle prompts/get request
  MCPResponse _handlePromptGet(MCPRequest request) {
    final params = request.params;
    if (params == null) {
      return MCPResponse(
        id: request.id,
        error: MCPError(code: -32602, message: 'Missing parameters'),
      );
    }

    final promptName = params['name'] as String?;
    if (promptName == null) {
      return MCPResponse(
        id: request.id,
        error: MCPError(code: -32602, message: 'Missing prompt name'),
      );
    }

    final handler = _promptHandlers[promptName];
    if (handler == null) {
      return MCPResponse(
        id: request.id,
        error: MCPError(code: -32601, message: 'Prompt not found: $promptName'),
      );
    }

    try {
      final arguments = params['arguments'] as Map<String, dynamic>? ?? {};
      final result = handler(arguments);

      return MCPResponse(
        id: request.id,
        result: {
          'description': _prompts[promptName]?.description ?? '',
          'messages': [
            {
              'role': 'user',
              'content': {'type': 'text', 'text': result},
            },
          ],
        },
      );
    } catch (e) {
      return MCPResponse(
        id: request.id,
        error: MCPError(code: -32603, message: 'Prompt execution error: $e'),
      );
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
      final router = Router<Handler>()
        ..get('/health', respondWith(_httpHandlers.healthCheckHandler))
        ..get('/status', respondWith(_httpHandlers.statusHandler))
        ..get('/ws', respondWith(_httpHandlers.webSocketUpgradeHandler))
        ..get('/mcp', respondWith(_httpHandlers.mcpSseHandler))
        ..get('/sse', respondWith(_httpHandlers.mcpSseHandler))
        ..post('/mcp', respondWith(_httpHandlers.mcpPostHandler));

      // Setup middleware pipeline with proper error handling
      final pipeline = Pipeline()
          .addMiddleware(corsMiddleware(enableCors))
          .addMiddleware(loggingMiddleware(_logger))
          .addMiddleware(errorHandlingMiddleware(_logger))
          .addMiddleware(routeWith(router));

      // Create handler with 404 fallback
      final handler = pipeline.addHandler(
        respondWith(
          (request) => Response.notFound(
            body: Body.fromString('MCP Server - Endpoint not found'),
          ),
        ),
      );

      // Start the Relic server using io_adapter serve function
      final httpServer = await HttpServer.bind(address, port);
      final adapter = io_adapter.IOAdapter(httpServer);
      _server = RelicServer(adapter);
      await _server!.mountAndStart(handler);

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
    final staleConnections = <WebSocket>[];

    for (final connection in _activeConnections) {
      if (connection.readyState == WebSocket.closed ||
          connection.readyState == WebSocket.closing) {
        staleConnections.add(connection);
      }
    }

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
