import 'package:test/test.dart';
import 'package:mcp_server_dart/src/server/session_manager.dart';
import 'dart:async';

void main() {
  group('SessionManager Header Storage', () {
    late SessionManager sessionManager;

    setUp(() {
      sessionManager = SessionManager();
    });

    test('should store and retrieve headers for a session', () {
      final sessionId = sessionManager.generateSessionId();
      final headers = {
        'authorization': 'Bearer token123',
        'x-request-id': 'req-456',
        'user-agent': 'test-client/1.0',
      };

      sessionManager.setSessionHeaders(sessionId, headers);

      final retrievedHeaders = sessionManager.getSessionHeaders(sessionId);
      expect(retrievedHeaders, isNotNull);
      expect(retrievedHeaders, equals(headers));
      expect(retrievedHeaders!['authorization'], equals('Bearer token123'));
      expect(retrievedHeaders['x-request-id'], equals('req-456'));
    });

    test('should return null for non-existent session headers', () {
      final sessionId = sessionManager.generateSessionId();
      final headers = sessionManager.getSessionHeaders(sessionId);
      expect(headers, isNull);
    });

    test('should update headers for existing session', () {
      final sessionId = sessionManager.generateSessionId();
      final initialHeaders = {'authorization': 'Bearer token123'};
      final updatedHeaders = {
        'authorization': 'Bearer new-token',
        'x-request-id': 'req-789',
      };

      sessionManager.setSessionHeaders(sessionId, initialHeaders);
      sessionManager.setSessionHeaders(sessionId, updatedHeaders);

      final retrievedHeaders = sessionManager.getSessionHeaders(sessionId);
      expect(retrievedHeaders, equals(updatedHeaders));
      expect(retrievedHeaders!['authorization'], equals('Bearer new-token'));
      expect(retrievedHeaders['x-request-id'], equals('req-789'));
    });

    test('should remove headers when SSE session is removed', () {
      final sessionId = sessionManager.generateSessionId();
      final controller = StreamController<String>();
      final headers = {'authorization': 'Bearer token123'};

      sessionManager.addSseSession(sessionId, controller, headers: headers);
      expect(sessionManager.getSessionHeaders(sessionId), isNotNull);

      // Remove session should clean up headers
      sessionManager.removeSseSession(sessionId);

      expect(sessionManager.getSessionHeaders(sessionId), isNull);

      controller.close();
    });

    test('should store headers when adding SSE session', () {
      final sessionId = sessionManager.generateSessionId();
      final controller = StreamController<String>();
      final headers = {
        'authorization': 'Bearer token123',
        'x-request-id': 'req-456',
      };

      sessionManager.addSseSession(sessionId, controller, headers: headers);

      final retrievedHeaders = sessionManager.getSessionHeaders(sessionId);
      expect(retrievedHeaders, isNotNull);
      expect(retrievedHeaders, equals(headers));

      controller.close();
    });

    test('should handle SSE session without headers', () {
      final sessionId = sessionManager.generateSessionId();
      final controller = StreamController<String>();

      sessionManager.addSseSession(sessionId, controller);

      final retrievedHeaders = sessionManager.getSessionHeaders(sessionId);
      expect(retrievedHeaders, isNull);

      controller.close();
    });
  });
}
