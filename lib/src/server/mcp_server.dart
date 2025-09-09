/// Base MCP Server implementation
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:relic/io_adapter.dart' as io_adapter;
import 'package:relic/relic.dart';

import 'package:dart_mcp/src/protocol/types.dart';

// Re-export for generated code
export 'package:dart_mcp/src/protocol/types.dart' show MCPResourceContent;

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

  MCPServer({required this.name, this.version = '1.0.0', this.description});

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
      switch (request.method) {
        case 'initialize':
          return _handleInitialize(request);
        case 'tools/list':
          return _handleToolsList(request);
        case 'tools/call':
          return await _handleToolCall(request);
        case 'resources/list':
          return _handleResourcesList(request);
        case 'resources/read':
          return await _handleResourceRead(request);
        case 'prompts/list':
          return _handlePromptsList(request);
        case 'prompts/get':
          return _handlePromptGet(request);
        default:
          return MCPResponse(
            id: request.id,
            error: MCPError(
              code: -32601,
              message: 'Method not found: ${request.method}',
            ),
          );
      }
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

  /// Connection tracking for health monitoring
  final Set<WebSocket> _activeConnections = <WebSocket>{};
  RelicServer? _server;
  Timer? _connectionMonitor;
  late final DateTime _startTime;

  /// Session management for Streamable HTTP
  final Map<String, StreamController<String>> _activeSessions = {};
  final Map<String, DateTime> _sessionTimestamps = {};
  final Map<String, int> _sessionEventIds = {};
  static const Duration _sessionTimeout = Duration(minutes: 30);

  /// Start production-ready HTTP server with WebSocket support using Relic
  Future<void> serve({
    int port = 8080,
    InternetAddress? address,
    bool enableCors = true,
    Duration keepAliveTimeout = const Duration(seconds: 30),
  }) async {
    address ??= InternetAddress.loopbackIPv4;
    _startTime = DateTime.now();

    _logger.info('Starting MCP Server on ${address.address}:$port');
    print('🔥 Starting MCP Server on ${address.address}:$port');

    try {
      // Setup router with health check, status, and MCP endpoints
      final router = Router<Handler>()
        ..get('/health', respondWith(_healthCheckHandler))
        ..get('/status', respondWith(_statusHandler))
        ..get('/ws', respondWith(_webSocketUpgradeHandler))
        ..get('/mcp', respondWith(_mcpSseHandler))
        ..post('/mcp', respondWith(_mcpPostHandler));

      // Setup middleware pipeline with proper error handling
      final pipeline = Pipeline()
          .addMiddleware(_corsMiddleware(enableCors))
          .addMiddleware(_loggingMiddleware())
          .addMiddleware(_errorHandlingMiddleware())
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
      _setupSignalHandlers();

      // Start connection monitoring
      _startConnectionMonitoring(keepAliveTimeout);
    } catch (e, stackTrace) {
      _logger.severe('Failed to start server: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Health check endpoint handler
  Response _healthCheckHandler(Request request) {
    final healthData = {
      'status': 'healthy',
      'timestamp': DateTime.now().toIso8601String(),
      'server': name,
      'version': version,
      'connections': _activeConnections.length,
      'tools': _tools.length,
      'resources': _resources.length,
      'prompts': _prompts.length,
    };

    return Response.ok(
      body: Body.fromString(jsonEncode(healthData), mimeType: MimeType.json),
      headers: Headers.fromMap({
        'content-type': ['application/json'],
      }),
    );
  }

  /// Server status endpoint handler
  Response _statusHandler(Request request) {
    final statusData = {
      'server': {'name': name, 'version': version, 'description': description},
      'capabilities': {
        'tools': _tools.keys.toList(),
        'resources': _resources.keys.toList(),
        'prompts': _prompts.keys.toList(),
      },
      'metrics': {
        'active_connections': _activeConnections.length,
        'uptime': DateTime.now().difference(_startTime).inSeconds,
      },
    };

    return Response.ok(
      body: Body.fromString(jsonEncode(statusData), mimeType: MimeType.json),
      headers: Headers.fromMap({
        'content-type': ['application/json'],
      }),
    );
  }

  /// WebSocket upgrade handler (placeholder - WebSocket support to be added)
  Response _webSocketUpgradeHandler(Request request) {
    // For now, return a message indicating WebSocket support is coming
    return Response.notImplemented(
      body: Body.fromString('WebSocket support coming soon'),
      headers: Headers.fromMap({
        'content-type': ['text/plain'],
      }),
    );
  }

  /// MCP POST handler for Streamable HTTP transport
  Future<Response> _mcpPostHandler(Request request) async {
    try {
      // Validate Origin header for security
      final origin = request.headers['origin']?.first;
      if (origin != null && !_isValidOrigin(origin)) {
        return Response.forbidden(body: Body.fromString('Invalid origin'));
      }

      // Check for session ID
      final sessionId = request.headers['mcp-session-id']?.first;

      // Parse JSON-RPC message from body
      final bodyBytes = <int>[];
      await for (final chunk in request.body.read()) {
        bodyBytes.addAll(chunk);
      }
      final bodyString = utf8.decode(bodyBytes);
      final jsonData = jsonDecode(bodyString);
      final mcpRequest = MCPRequest.fromJson(jsonData);

      // Handle initialization specially to potentially create session
      if (mcpRequest.method == 'initialize') {
        final response = await handleRequest(mcpRequest);
        final responseJson = response.toJson();

        // Create session ID for this client if not provided
        String? newSessionId;
        if (sessionId == null) {
          newSessionId = _generateSessionId();
          _sessionTimestamps[newSessionId] = DateTime.now();
          _sessionEventIds[newSessionId] = 0;
        }

        final headers = Headers.fromMap({
          'content-type': ['application/json'],
          'mcp-protocol-version': ['2025-06-18'],
          if (newSessionId != null) 'mcp-session-id': [newSessionId],
        });

        return Response.ok(
          body: Body.fromString(
            jsonEncode(responseJson),
            mimeType: MimeType.json,
          ),
          headers: headers,
        );
      }

      // Validate session for non-initialization requests
      if (sessionId != null) {
        if (!_isValidSession(sessionId)) {
          return Response.notFound(
            body: Body.fromString('Session not found or expired'),
          );
        }
        _sessionTimestamps[sessionId] = DateTime.now(); // Update timestamp
      }

      // // For non-initialize requests, check if SSE is requested
      // final acceptHeader = request.headers['accept']?.first ?? '';
      // if (acceptHeader.contains('text/event-stream')) {
      //   // Use SSE response for streaming
      //   return _createSseResponse(mcpRequest, sessionId);
      // }

      // Return JSON response by default
      final response = await handleRequest(mcpRequest);
      return Response.ok(
        body: Body.fromString(
          jsonEncode(response.toJson()),
          mimeType: MimeType.json,
        ),
        headers: Headers.fromMap({
          'content-type': ['application/json'],
          'mcp-protocol-version': ['2025-06-18'],
        }),
      );
    } catch (e, stackTrace) {
      _logger.severe('Error in MCP POST handler: $e', e, stackTrace);
      return Response.badRequest(
        body: Body.fromString(
          jsonEncode({
            'jsonrpc': '2.0',
            'error': {'code': -32700, 'message': 'Parse error: $e'},
          }),
          mimeType: MimeType.json,
        ),
        headers: Headers.fromMap({
          'content-type': ['application/json'],
        }),
      );
    }
  }

  /// MCP GET handler for SSE streams
  Response _mcpSseHandler(Request request) {
    try {
      // Validate Origin header for security
      final origin = request.headers['origin']?.first;
      if (origin != null && !_isValidOrigin(origin)) {
        return Response.forbidden(body: Body.fromString('Invalid origin'));
      }

      // Check Accept header
      final acceptHeader = request.headers['accept']?.first ?? '';
      if (!acceptHeader.contains('text/event-stream')) {
        return Response(
          405,
          body: Body.fromString(
            'Method Not Allowed - requires text/event-stream',
          ),
          headers: Headers.fromMap({
            'allow': ['POST'],
          }),
        );
      }

      // Create SSE stream for server-initiated messages
      final controller = StreamController<String>();
      final sessionId = _generateSessionId();

      _activeSessions[sessionId] = controller;
      _sessionTimestamps[sessionId] = DateTime.now();
      _sessionEventIds[sessionId] = 0;

      // Setup stream cleanup
      controller.onCancel = () {
        _activeSessions.remove(sessionId);
        _sessionTimestamps.remove(sessionId);
        _sessionEventIds.remove(sessionId);
      };

      // Send initial connection event
      _sendSseEvent(controller, 'connected', {
        'sessionId': sessionId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return Response.ok(
        body: Body.fromDataStream(
          controller.stream.map(
            (data) => Uint8List.fromList(utf8.encode(data)),
          ),
          mimeType: MimeType.parse('text/event-stream'),
        ),
        headers: Headers.fromMap({
          'content-type': ['text/event-stream'],
          'cache-control': ['no-cache'],
          'connection': ['keep-alive'],
          'access-control-allow-origin': ['*'],
          'mcp-protocol-version': ['2025-06-18'],
          'mcp-session-id': [sessionId],
        }),
      );
    } catch (e, stackTrace) {
      _logger.severe('Error in MCP SSE handler: $e', e, stackTrace);
      return Response.internalServerError(
        body: Body.fromString('Internal server error'),
      );
    }
  }

  /// CORS middleware
  Middleware _corsMiddleware(bool enabled) {
    return (Handler innerHandler) {
      return (NewContext context) async {
        if (!enabled) return await innerHandler(context);

        final request = context.request;

        // Handle preflight requests
        if (request.method == RequestMethod.options) {
          return context.respond(
            Response.ok(
              headers: Headers.fromMap({
                'Access-Control-Allow-Origin': ['*'],
                'Access-Control-Allow-Methods': ['GET, POST, OPTIONS'],
                'Access-Control-Allow-Headers': ['Content-Type, Authorization'],
                'Access-Control-Max-Age': ['86400'],
              }),
            ),
          );
        }

        // Process request and add CORS headers to response
        final result = await innerHandler(context);
        if (result is ResponseContext) {
          return result.respond(
            result.response.copyWith(
              headers: result.response.headers.transform((mh) {
                mh['Access-Control-Allow-Origin'] = ['*'];
              }),
            ),
          );
        }
        return result;
      };
    };
  }

  /// Logging middleware
  Middleware _loggingMiddleware() {
    return (Handler innerHandler) {
      return (NewContext context) async {
        final stopwatch = Stopwatch()..start();
        final request = context.request;

        _logger.info(
          '${request.method.value.toUpperCase()} ${request.url.path}',
        );

        try {
          final result = await innerHandler(context);
          stopwatch.stop();

          if (result is ResponseContext) {
            _logger.info(
              '${request.method.value.toUpperCase()} ${request.url.path} '
              '${result.response.statusCode} ${stopwatch.elapsedMilliseconds}ms',
            );
          }

          return result;
        } catch (e) {
          stopwatch.stop();
          _logger.warning(
            '${request.method.value.toUpperCase()} ${request.url.path} '
            'ERROR ${stopwatch.elapsedMilliseconds}ms: $e',
          );
          rethrow;
        }
      };
    };
  }

  /// Error handling middleware
  Middleware _errorHandlingMiddleware() {
    return (Handler innerHandler) {
      return (NewContext context) async {
        try {
          return await innerHandler(context);
        } catch (e, stackTrace) {
          _logger.severe(
            'Unhandled error in request handler: $e',
            e,
            stackTrace,
          );

          return context.respond(
            Response.internalServerError(
              body: Body.fromString('Internal server error'),
            ),
          );
        }
      };
    };
  }

  /// Setup signal handlers for graceful shutdown
  void _setupSignalHandlers() {
    ProcessSignal.sigint.watch().listen((_) async {
      _logger.info('Received SIGINT, shutting down gracefully...');
      await shutdown();
      exit(0);
    });

    ProcessSignal.sigterm.watch().listen((_) async {
      _logger.info('Received SIGTERM, shutting down gracefully...');
      await shutdown();
      exit(0);
    });
  }

  /// Start connection monitoring and cleanup
  void _startConnectionMonitoring(Duration keepAliveTimeout) {
    _connectionMonitor = Timer.periodic(keepAliveTimeout, (timer) {
      _cleanupStaleConnections();
      _cleanupExpiredSessions();
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

  /// Helper methods for Streamable HTTP support

  /// Generate a cryptographically secure session ID
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'mcp_${timestamp}_${random.toRadixString(16)}';
  }

  /// Validate if a session is still active and not expired
  bool _isValidSession(String sessionId) {
    final timestamp = _sessionTimestamps[sessionId];
    if (timestamp == null) return false;

    final now = DateTime.now();
    return now.difference(timestamp) < _sessionTimeout;
  }

  /// Validate origin header for security (basic implementation)
  bool _isValidOrigin(String origin) {
    // For localhost development, allow localhost origins
    if (origin.startsWith('http://localhost') ||
        origin.startsWith('http://127.0.0.1')) {
      return true;
    }

    // In production, you should validate against allowed origins
    // For now, reject all non-localhost origins for security
    return false;
  }

  /// Create SSE response with JSON-RPC message
  // ignore: unused_element
  Response _createSseResponse(MCPRequest request, String? sessionId) {
    final controller = StreamController<String>();

    // Process request asynchronously and stream the response
    _processRequestForSse(request, controller, sessionId);

    return Response.ok(
      body: Body.fromDataStream(
        controller.stream.map((data) => Uint8List.fromList(utf8.encode(data))),
        mimeType: MimeType.parse('text/event-stream'),
      ),
      headers: Headers.fromMap({
        'content-type': ['text/event-stream'],
        'cache-control': ['no-cache'],
        'connection': ['keep-alive'],
        'access-control-allow-origin': ['*'],
        'mcp-protocol-version': ['2025-06-18'],
        if (sessionId != null) 'mcp-session-id': [sessionId],
      }),
    );
  }

  /// Process MCP request and send response via SSE
  Future<void> _processRequestForSse(
    MCPRequest request,
    StreamController<String> controller,
    String? sessionId,
  ) async {
    try {
      final response = await handleRequest(request);
      final eventId = sessionId != null ? _getNextEventId(sessionId) : null;

      _sendSseEvent(
        controller,
        'message',
        response.toJson(),
        eventId: eventId?.toString(),
      );

      // Close stream after sending response
      await controller.close();
    } catch (e) {
      _sendSseEvent(controller, 'error', {
        'jsonrpc': '2.0',
        'id': request.id,
        'error': {'code': -32603, 'message': 'Internal error: $e'},
      });
      await controller.close();
    }
  }

  /// Send an SSE event
  void _sendSseEvent(
    StreamController<String> controller,
    String event,
    Map<String, dynamic> data, {
    String? eventId,
  }) {
    final buffer = StringBuffer();

    if (eventId != null) {
      buffer.writeln('id: $eventId');
    }
    buffer.writeln('event: $event');
    buffer.writeln('data: ${jsonEncode(data)}');
    buffer.writeln(); // Empty line to end the event

    if (!controller.isClosed) {
      controller.add(buffer.toString());
    }
  }

  /// Get next event ID for a session
  int _getNextEventId(String sessionId) {
    final currentId = _sessionEventIds[sessionId] ?? 0;
    final nextId = currentId + 1;
    _sessionEventIds[sessionId] = nextId;
    return nextId;
  }

  /// Clean up expired sessions
  void _cleanupExpiredSessions() {
    final now = DateTime.now();
    final expiredSessions = <String>[];

    for (final entry in _sessionTimestamps.entries) {
      if (now.difference(entry.value) > _sessionTimeout) {
        expiredSessions.add(entry.key);
      }
    }

    for (final sessionId in expiredSessions) {
      final controller = _activeSessions.remove(sessionId);
      _sessionTimestamps.remove(sessionId);
      _sessionEventIds.remove(sessionId);

      if (controller != null && !controller.isClosed) {
        controller.close();
      }
    }

    if (expiredSessions.isNotEmpty) {
      _logger.info('Cleaned up ${expiredSessions.length} expired sessions');
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

    // Close all active SSE sessions
    final sessFutures = <Future>[];
    for (final controller in _activeSessions.values) {
      if (!controller.isClosed) {
        sessFutures.add(controller.close());
      }
    }

    if (sessFutures.isNotEmpty) {
      await Future.wait(sessFutures, eagerError: false);
      _logger.info('Closed ${sessFutures.length} SSE sessions');
    }

    _activeSessions.clear();
    _sessionTimestamps.clear();
    _sessionEventIds.clear();

    // Close Relic server
    if (_server != null) {
      await _server!.close();
      _logger.info('Relic server closed');
    }

    _logger.info('✓ MCP Server shutdown complete');
  }

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
