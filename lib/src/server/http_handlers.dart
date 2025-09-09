/// HTTP request handlers for MCP server
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:relic/relic.dart';

import 'package:mcp_server_dart/src/protocol/types.dart';
import 'session_manager.dart';
import 'server_utils.dart';

/// HTTP request handlers for MCP server
class HttpHandlers {
  final Logger _logger = Logger('HttpHandlers');
  final SessionManager _sessionManager;
  final String serverName;
  final String serverVersion;
  final String? serverDescription;
  final DateTime startTime;
  final bool validateOrigins;
  final bool allowLocalhost;
  final List<String> allowedOrigins;

  // Server state
  final Map<String, MCPToolDefinition> tools;
  final Map<String, MCPResourceDefinition> resources;
  final Map<String, MCPPromptDefinition> prompts;
  final Set<WebSocket> activeConnections;
  final Future<MCPResponse> Function(MCPRequest) handleRequest;

  HttpHandlers({
    required this.serverName,
    required this.serverVersion,
    required this.serverDescription,
    required this.startTime,
    required this.validateOrigins,
    required this.allowLocalhost,
    required this.allowedOrigins,
    required this.tools,
    required this.resources,
    required this.prompts,
    required this.activeConnections,
    required this.handleRequest,
    required SessionManager sessionManager,
  }) : _sessionManager = sessionManager;

  /// Health check endpoint handler
  Response healthCheckHandler(Request request) {
    final healthData = {
      'status': 'healthy',
      'timestamp': DateTime.now().toIso8601String(),
      'server': serverName,
      'version': serverVersion,
      'connections': activeConnections.length,
      'tools': tools.length,
      'resources': resources.length,
      'prompts': prompts.length,
    };

    return Response.ok(
      body: Body.fromString(jsonEncode(healthData), mimeType: MimeType.json),
      headers: Headers.fromMap({
        'content-type': ['application/json'],
      }),
    );
  }

  /// Server status endpoint handler
  Response statusHandler(Request request) {
    final statusData = {
      'server': {
        'name': serverName,
        'version': serverVersion,
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
    };

    return Response.ok(
      body: Body.fromString(jsonEncode(statusData), mimeType: MimeType.json),
      headers: Headers.fromMap({
        'content-type': ['application/json'],
      }),
    );
  }

  /// WebSocket upgrade handler (placeholder - WebSocket support to be added)
  Response webSocketUpgradeHandler(Request request) {
    // For now, return a message indicating WebSocket support is coming
    return Response.notImplemented(
      body: Body.fromString('WebSocket support coming soon'),
      headers: Headers.fromMap({
        'content-type': ['text/plain'],
      }),
    );
  }

  /// MCP POST handler for Streamable HTTP transport
  Future<Response> mcpPostHandler(Request request) async {
    try {
      // Validate Origin header for security
      if (validateOrigins) {
        final origin = request.headers['origin']?.first;
        if (!ServerUtils.isValidOrigin(
          origin,
          validateOrigins: validateOrigins,
          allowLocalhost: allowLocalhost,
          allowedOrigins: allowedOrigins,
        )) {
          return Response.forbidden(body: Body.fromString('Invalid origin'));
        }
      }

      // Check for session ID
      var sessionId = request.headers['mcp-session-id']?.first;

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
        if (sessionId == null) {
          sessionId = _sessionManager.generateSessionId();
          _sessionManager.createSession(sessionId);
        }

        final headers = Headers.fromMap({
          'content-type': ['application/json'],
          'mcp-protocol-version': ['2025-06-18'],
          'mcp-session-id': [sessionId],
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
        if (!_sessionManager.isValidSession(sessionId)) {
          return Response.notFound(
            body: Body.fromString('Session not found or expired'),
          );
        }
        _sessionManager.updateSession(sessionId); // Update timestamp
      }

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
  Response mcpSseHandler(Request request) {
    try {
      // Validate Origin header for security
      if (validateOrigins) {
        final origin = request.headers['origin']?.first;
        if (!ServerUtils.isValidOrigin(
          origin,
          validateOrigins: validateOrigins,
          allowLocalhost: allowLocalhost,
          allowedOrigins: allowedOrigins,
        )) {
          return Response.forbidden(body: Body.fromString('Invalid origin'));
        }
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
      final sessionId = _sessionManager.generateSessionId();

      _sessionManager.addSseSession(sessionId, controller);

      // Send initial connection event
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

  /// Create SSE response with JSON-RPC message
  Response createSseResponse(MCPRequest request, String? sessionId) {
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
