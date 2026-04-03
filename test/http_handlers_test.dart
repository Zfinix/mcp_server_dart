import 'dart:convert';
import 'dart:async';

import 'package:mcp_server_dart/src/protocol/types.dart';
import 'package:mcp_server_dart/src/server/http_handlers.dart';
import 'package:mcp_server_dart/src/server/session_manager.dart';
import 'package:relic/relic.dart';
import 'package:relic/src/context/context.dart';
import 'package:test/test.dart';

Request _request(
  Method method,
  String url, {
  Map<String, List<String>>? headers,
  String? body,
}) {
  return RequestInternal.create(
    method,
    Uri.parse(url),
    Object(),
    headers: headers == null ? null : Headers.fromMap(headers),
    body: body == null ? null : Body.fromString(body, mimeType: MimeType.json),
  );
}

Future<HttpHandlers> _createHandlers({
  Future<MCPResponse> Function(MCPRequest request)? onHandleRequest,
}) async {
  final sessionManager = SessionManager();
  return HttpHandlers(
    serverName: 'test-server',
    serverVersion: '1.0.0',
    serverProtocolVersion: '2025-11-25',
    serverDescription: 'Test server',
    startTime: DateTime.now(),
    validateOrigins: false,
    allowLocalhost: true,
    allowedOrigins: const [],
    tools: const {},
    resources: const {},
    prompts: const {},
    activeConnections: <RelicWebSocket>{},
    handleRequest: onHandleRequest ??
        ((request) async => MCPResponse(id: request.id, result: {'ok': true})),
    sessionManager: sessionManager,
  );
}

void main() {
  group('HttpHandlers Streamable HTTP', () {
    test('initialize creates a server session even when client provides session id', () async {
      final handlers = await _createHandlers();

      final initRequest = _request(
        Method.post,
        'http://localhost/mcp',
        headers: {
          'mcp-session-id': ['client-session-123'],
          'content-type': ['application/json'],
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': '1',
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-11-25',
            'capabilities': {},
            'clientInfo': {'name': 'test-client', 'version': '1.0.0'},
          },
        }),
      );

      final initResponse = await handlers.mcpPostHandler(initRequest);
      expect(initResponse.statusCode, equals(200));
      expect(
        initResponse.headers['mcp-session-id']?.first,
        equals('client-session-123'),
      );

      final followupRequest = _request(
        Method.post,
        'http://localhost/mcp',
        headers: {
          'mcp-session-id': ['client-session-123'],
          'content-type': ['application/json'],
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': '2',
          'method': 'tools/list',
        }),
      );

      final followupResponse = await handlers.mcpPostHandler(followupRequest);
      expect(followupResponse.statusCode, equals(200));
      expect(
        followupResponse.headers['mcp-session-id']?.first,
        equals('client-session-123'),
      );
    });

    test('non-initialize POST rejects unknown session ids', () async {
      final handlers = await _createHandlers();

      final request = _request(
        Method.post,
        'http://localhost/mcp',
        headers: {
          'mcp-session-id': ['missing-session'],
          'content-type': ['application/json'],
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': '1',
          'method': 'tools/list',
        }),
      );

      final response = await handlers.mcpPostHandler(request);
      expect(response.statusCode, equals(404));
      expect(await response.readAsString(), contains('Session not found or expired'));
    });

    test('SSE session stores forwarded headers and reuses them for later responses', () async {
      late MCPRequest capturedRequest;
      final handlers = await _createHandlers(
        onHandleRequest: (request) async {
          capturedRequest = request;
          return MCPResponse(
            id: request.id,
            result: {
              'headers': request.headers,
            },
          );
        },
      );

      final sseConnectRequest = _request(
        Method.get,
        'http://localhost/mcp',
        headers: {
          'accept': ['text/event-stream'],
          'authorization': ['Bearer weather-token'],
          'x-request-id': ['req-42'],
          'x-ignored-header': ['should-not-forward'],
        },
      );

      final sseConnectResponse = handlers.mcpSseHandler(sseConnectRequest);
      expect(sseConnectResponse.statusCode, equals(200));
      final sessionId = sseConnectResponse.headers['mcp-session-id']?.first;
      expect(sessionId, isNotNull);

      final sseMessageResponse = handlers.createSseResponse(
        MCPRequest(method: 'tools/list', id: 'msg-1'),
        sessionId,
      );

      final body = await sseMessageResponse.readAsString();
      expect(body, contains('event: message'));
      final forwardedHeaders = capturedRequest.headers!;
      expect(forwardedHeaders['authorization'], equals('Bearer weather-token'));
      expect(forwardedHeaders['x-request-id'], equals('req-42'));
      expect(forwardedHeaders.containsKey('x-ignored-header'), isFalse);
    });

    test('SSE GET requires text/event-stream accept header', () async {
      final handlers = await _createHandlers();

      final request = _request(Method.get, 'http://localhost/mcp');
      final response = handlers.mcpSseHandler(request);

      expect(response.statusCode, equals(405));
      expect(response.headers['allow']?.first, equals('POST'));
      expect(
        await response.readAsString(),
        contains('requires text/event-stream'),
      );
    });
  });
}
