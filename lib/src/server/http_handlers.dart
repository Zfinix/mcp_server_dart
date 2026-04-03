/// HTTP request handlers for MCP server
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:mcp_server_dart/src/server/middleware.dart';
import 'package:relic/relic.dart';
import 'package:web_socket/web_socket.dart';

import 'package:mcp_server_dart/src/protocol/types.dart';
import 'session_manager.dart';
import 'server_utils.dart';

/// HTTP request handlers for MCP server
class HttpHandlers {
  final Logger _logger = Logger('HttpHandlers');
  final SessionManager _sessionManager;
  final String serverName;
  final String serverVersion;
  final String serverProtocolVersion;
  final String? serverDescription;
  final DateTime startTime;
  final bool validateOrigins;
  final bool allowLocalhost;
  final List<String> allowedOrigins;
  final Set<String>? allowedHeaders;

  // Server state
  final Map<String, MCPToolDefinition> tools;
  final Map<String, MCPResourceDefinition> resources;
  final Map<String, MCPPromptDefinition> prompts;
  final Set<RelicWebSocket> activeConnections;
  final Future<MCPResponse> Function(MCPRequest) handleRequest;
  final bool authEnabled;
  final TokenValidator validateToken;

  HttpHandlers({
    required this.serverName,
    required this.serverVersion,
    required this.serverProtocolVersion,
    required this.serverDescription,
    required this.startTime,
    required this.validateOrigins,
    required this.allowLocalhost,
    required this.allowedOrigins,
    this.allowedHeaders,
    required this.tools,
    required this.resources,
    required this.prompts,
    required this.activeConnections,
    required this.handleRequest,
    required SessionManager sessionManager,
    this.authEnabled = false,
    TokenValidator? validateToken,
  }) : _sessionManager = sessionManager,
       validateToken = validateToken ?? defaultTokenValidator;

  /// Health check endpoint handler
  Response healthCheckHandler(Request request) {
    return _jsonResponse({
      'status': 'healthy',
      'timestamp': DateTime.now().toIso8601String(),
      'server': serverName,
      'version': serverVersion,
      'connections': activeConnections.length,
      'tools': tools.length,
      'resources': resources.length,
      'prompts': prompts.length,
    });
  }

  /// Server status endpoint handler
  Response statusHandler(Request request) {
    return _jsonResponse({
      'server': {
        'name': serverName,
        'version': serverVersion,
        'protocol_version': serverProtocolVersion,
        'description': serverDescription,
      },
      'capabilities': {
        'tools': tools.keys.toList(),
        'resources': resources.keys.toList(),
        'prompts': prompts.keys.toList(),
      },
      'metrics': {
        'active_connections': activeConnections.length,
        'uptime': DateTime.now().difference(startTime).inSeconds,
      },
    });
  }

  /// Validate authentication token from WebSocket upgrade request
  Future<bool> _validateWebSocketAuth(Request request) async {
    if (!authEnabled) return true;

    // Check for token in query parameters or headers
    final token =
        request.url.queryParameters['token'] ??
        request.headers.authorization?.headerValue.replaceFirst('Bearer ', '');

    if (token == null || token.isEmpty) {
      _logger.warning(
        'WebSocket connection rejected: No authentication token provided',
      );
      return false;
    }

    final isValid = await validateToken(token);
    if (!isValid) {
      _logger.warning(
        'WebSocket connection rejected: Invalid authentication token',
      );
    }

    return isValid;
  }

  /// WebSocket upgrade handler for MCP protocol over WebSockets
  WebSocketUpgrade webSocketUpgradeHandler(final Request request) {
    // Extract headers to forward to WebSocket messages
    final forwardedHeaders = _extractForwardedHeaders(request.headers);

    return WebSocketUpgrade((final webSocket) async {
      // Validate authentication if enabled
      if (authEnabled) {
        final isValid = await _validateWebSocketAuth(request);
        if (!isValid) {
          webSocket.close(4001, 'Authentication required');
          return;
        }
      }

      // Get or create session ID
      final sessionId =
          request.headers['mcp-session-id']?.first ??
          _sessionManager.generateSessionId();

      if (!_sessionManager.isValidSession(sessionId)) {
        _sessionManager.createSession(sessionId);
        _sessionManager.addWebSocketSession(sessionId, webSocket);
      } else {
        _sessionManager.updateSession(sessionId);
      }

      // Store the headers in the WebSocket context
      _webSocketHeadersProperty[request] = forwardedHeaders;

      _logger.info('WebSocket connection established for session $sessionId');
      activeConnections.add(webSocket);

      // Send welcome message
      webSocket.sendText(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'welcome',
          'params': {
            'server': serverName,
            'version': serverVersion,
            'sessionId': sessionId,
          },
        }),
      );

      // Handle incoming messages
      await for (final event in webSocket.events) {
        switch (event) {
          case TextDataReceived(text: final message):
            _handleWebSocketMessage(request, webSocket, message, sessionId);
          case CloseReceived():
            _logger.info('WebSocket connection closed for session $sessionId');
            activeConnections.remove(webSocket);
            _sessionManager.removeWebSocketSession(sessionId);
            break;
          default:
            // Handle other event types if needed
            break;
        }
      }
    });
  }

  /// Send an error response through WebSocket
  void _sendErrorResponse(
    RelicWebSocket webSocket,
    int code,
    String message, [
    dynamic error,
  ]) {
    try {
      webSocket.sendText(
        jsonEncode({
          'jsonrpc': '2.0',
          'error': {
            'code': code,
            'message': message,
            if (error != null) 'data': error.toString(),
          },
        }),
      );
    } catch (e) {
      _logger.severe('Failed to send error response', e);
      webSocket.close(1011, 'Failed to process message');
    }
  }

  /// Parse and validate WebSocket message
  MCPRequest _parseWebSocketMessage(String message, Request request) {
    if (message.trim().isEmpty) {
      throw const FormatException('Empty message received');
    }

    final requestJson = jsonDecode(message) as Map<String, dynamic>;
    if (requestJson['jsonrpc'] != '2.0') {
      throw const FormatException('Invalid JSON-RPC version');
    }

    var mcpRequest = MCPRequest.fromJson(requestJson);

    // Add stored headers from WebSocket context
    try {
      if (request.mcpHeaders.isNotEmpty) {
        mcpRequest = mcpRequest.withHeaders(request.mcpHeaders);
      }
    } catch (e, st) {
      _logger.warning('Failed to process WebSocket headers', e, st);
      // Continue without headers rather than failing the request
    }

    return mcpRequest;
  }

  /// Process incoming WebSocket messages
  void _handleWebSocketMessage(
    Request request,
    RelicWebSocket webSocket,
    String message,
    String sessionId,
  ) async {
    try {
      final mcpRequest = _parseWebSocketMessage(message, request);
      final response = await handleRequest(mcpRequest);
      webSocket.sendText(jsonEncode(response.toJson()));
    } on FormatException catch (e) {
      _logger.warning('Invalid message format: ${e.message}');
      _sendErrorResponse(webSocket, -32700, 'Parse error: ${e.message}');
    } on JsonUnsupportedObjectError catch (e) {
      _logger.warning('JSON serialization error', e);
      _sendErrorResponse(
        webSocket,
        -32603,
        'Internal error: Invalid response data',
      );
    } catch (e, stackTrace) {
      _logger.severe('Error processing WebSocket message', e, stackTrace);
      _sendErrorResponse(
        webSocket,
        -32603,
        'Internal error: ${e.toString().split('\n').first}',
        e,
      );
    }
  }

  /// Extract and filter headers to forward to MCP handlers
  Map<String, String> _extractForwardedHeaders(Headers headers) {
    // Use custom whitelist if provided, otherwise use default safe headers
    final headerWhitelist = {
      'authorization',
      'x-request-id',
      'x-forwarded-for',
      'user-agent',
      'accept-language',
      'content-type',
      ...?allowedHeaders,
    };

    final result = <String, String>{};
    for (final header in headers.entries) {
      final lowerName = header.key.toLowerCase();
      // Check if header is in whitelist (case-insensitive)
      final isAllowed = headerWhitelist.any(
        (allowed) => allowed.toLowerCase() == lowerName,
      );
      if (isAllowed && header.value.isNotEmpty) {
        result[header.key] = header.value.first;
      }
    }
    return result;
  }

  /// Validate origin header for CORS
  bool _validateOrigin(Request request) {
    if (!validateOrigins) return true;
    final origin = request.headers['origin']?.first;
    return ServerUtils.isValidOrigin(
      origin,
      validateOrigins: validateOrigins,
      allowLocalhost: allowLocalhost,
      allowedOrigins: allowedOrigins,
    );
  }

  /// Create JSON response with standard headers
  Response _jsonResponse(Map<String, dynamic> data) {
    return Response.ok(
      body: Body.fromString(jsonEncode(data), mimeType: MimeType.json),
      headers: _jsonHeaders(),
    );
  }

  /// Create standard JSON headers
  Headers _jsonHeaders() {
    return Headers.fromMap({
      'content-type': ['application/json'],
    });
  }

  /// Create MCP protocol headers
  Headers _mcpHeaders({String? sessionId}) {
    final headers = <String, List<String>>{
      'content-type': ['application/json'],
      'mcp-protocol-version': [serverProtocolVersion],
    };
    if (sessionId != null) {
      headers['mcp-session-id'] = [sessionId];
    }
    return Headers.fromMap(headers);
  }

  /// Create SSE headers
  Headers _sseHeaders({String? sessionId}) {
    final headers = <String, List<String>>{
      'content-type': ['text/event-stream'],
      'cache-control': ['no-cache'],
      'connection': ['keep-alive'],
      'access-control-allow-origin': ['*'],
      'mcp-protocol-version': [serverProtocolVersion],
    };
    if (sessionId != null) {
      headers['mcp-session-id'] = [sessionId];
    }
    return Headers.fromMap(headers);
  }

  /// Create error response
  Response _errorResponse(
    int statusCode,
    String message, {
    Map<String, dynamic>? errorData,
  }) {
    final error = {'jsonrpc': '2.0', if (errorData != null) ...errorData};
    return Response(
      statusCode,
      body: Body.fromString(jsonEncode(error), mimeType: MimeType.json),
      headers: _jsonHeaders(),
    );
  }

  /// MCP POST handler for Streamable HTTP transport
  Future<Response> mcpPostHandler(Request request) async {
    try {
      if (!_validateOrigin(request)) {
        return Response.forbidden(body: Body.fromString('Invalid origin'));
      }

      var sessionId = request.headers['mcp-session-id']?.first;
      final requestBody = await request.readAsString();
      final requestJson = jsonDecode(requestBody) as Map<String, dynamic>;
      var mcpRequest = MCPRequest.fromJson(requestJson);

      // Handle initialization specially to potentially create session
      if (mcpRequest.method == 'initialize') {
        // For initialization, always use headers from current request
        mcpRequest = mcpRequest.withHeaders(
          _extractForwardedHeaders(request.headers),
        );

        final response = await handleRequest(mcpRequest);
        sessionId ??= _sessionManager.generateSessionId();
        if (!_sessionManager.isValidSession(sessionId)) {
          _sessionManager.createSession(sessionId);
        } else {
          _sessionManager.updateSession(sessionId);
        }
        return Response.ok(
          body: Body.fromString(
            jsonEncode(response.toJson()),
            mimeType: MimeType.json,
          ),
          headers: _mcpHeaders(sessionId: sessionId),
        );
      }

      // Validate session for non-initialization requests
      if (sessionId != null) {
        if (!_sessionManager.isValidSession(sessionId)) {
          return Response.notFound(
            body: Body.fromString('Session not found or expired'),
          );
        }
        _sessionManager.updateSession(sessionId);

        // For SSE sessions, use stored headers if available
        final storedHeaders = _sessionManager.getSessionHeaders(sessionId);
        if (storedHeaders != null && storedHeaders.isNotEmpty) {
          mcpRequest = mcpRequest.withHeaders(storedHeaders);
        } else {
          // Fallback to extracting from current request (for WebSocket or non-SSE POST)
          mcpRequest = mcpRequest.withHeaders(
            _extractForwardedHeaders(request.headers),
          );
        }
      } else {
        // No session, use headers from current request
        mcpRequest = mcpRequest.withHeaders(
          _extractForwardedHeaders(request.headers),
        );
      }

      final response = await handleRequest(mcpRequest);
      return Response.ok(
        body: Body.fromString(
          jsonEncode(response.toJson()),
          mimeType: MimeType.json,
        ),
        headers: _mcpHeaders(sessionId: sessionId),
      );
    } catch (e, stackTrace) {
      _logger.severe('Error in MCP POST handler: $e', e, stackTrace);
      return _errorResponse(
        400,
        'Parse error',
        errorData: {
          'error': {'code': -32700, 'message': 'Parse error: $e'},
        },
      );
    }
  }

  /// MCP GET handler for SSE streams
  Response mcpSseHandler(Request request) {
    try {
      if (!_validateOrigin(request)) {
        return Response.forbidden(body: Body.fromString('Invalid origin'));
      }

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

      final controller = StreamController<String>();
      final sessionId = _sessionManager.generateSessionId();

      // Extract headers to forward to MCP handlers
      final forwardedHeaders = _extractForwardedHeaders(request.headers);

      _sessionManager.addSseSession(
        sessionId,
        controller,
        headers: forwardedHeaders,
      );
      _sessionManager.sendSseEvent(controller, 'connected', {
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
        headers: _sseHeaders(sessionId: sessionId),
      );
    } catch (e, stackTrace) {
      _logger.severe('Error in MCP SSE handler: $e', e, stackTrace);
      return Response.internalServerError(
        body: Body.fromString('Internal server error'),
      );
    }
  }

  /// Create SSE response with JSON-RPC message
  Response createSseResponse(MCPRequest request, String? sessionId) {
    final controller = StreamController<String>();
    _processRequestForSse(request, controller, sessionId);

    return Response.ok(
      body: Body.fromDataStream(
        controller.stream.map((data) => Uint8List.fromList(utf8.encode(data))),
        mimeType: MimeType.parse('text/event-stream'),
      ),
      headers: _sseHeaders(sessionId: sessionId),
    );
  }

  /// Process MCP request and send response via SSE
  Future<void> _processRequestForSse(
    MCPRequest request,
    StreamController<String> controller,
    String? sessionId,
  ) async {
    try {
      // Add stored headers from session if available
      if (sessionId != null) {
        final storedHeaders = _sessionManager.getSessionHeaders(sessionId);
        if (storedHeaders != null && storedHeaders.isNotEmpty) {
          request = request.withHeaders(storedHeaders);
        }
      }

      final response = await handleRequest(request);
      final eventId = sessionId != null
          ? _sessionManager.getNextEventId(sessionId)
          : null;

      _sessionManager.sendSseEvent(
        controller,
        'message',
        response.toJson(),
        eventId: eventId?.toString(),
      );

      // Close stream after sending response
      await controller.close();
    } catch (e) {
      _sessionManager.sendSseEvent(controller, 'error', {
        'jsonrpc': '2.0',
        'id': request.id,
        'error': {'code': -32603, 'message': 'Internal error: $e'},
      });
      await controller.close();
    }
  }
}

extension RequestIdExtension on Request {
  /// Get the request ID from the request context
  Map<String, String> get mcpHeaders => _webSocketHeadersProperty[this];
}

/// Context property for storing headers in WebSocket connections
final _webSocketHeadersProperty = ContextProperty<Map<String, String>>(
  'mcp_headers',
);
