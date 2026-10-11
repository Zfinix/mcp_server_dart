/// Session management for MCP server
library;

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:relic/relic.dart' hide Logger;

/// Session manager for handling HTTP sessions and SSE connections
class SessionManager {
  final Logger _logger = Logger('SessionManager');

  /// Active SSE sessions
  final Map<String, StreamController<String>> _activeSessions = {};
  final Map<String, RelicWebSocket> _activeWebSocketSessions = {};
  final Map<String, DateTime> _sessionTimestamps = {};
  final Map<String, int> _sessionEventIds = {};

  /// Headers stored per session (for SSE and WebSocket)
  final Map<String, Map<String, String>> _sessionHeaders = {};
  static const Duration _sessionTimeout = Duration(minutes: 30);

  /// Generate a cryptographically secure session ID
  String generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'mcp_${timestamp}_${random.toRadixString(16)}';
  }

  /// Validate if a session is still active and not expired
  bool isValidSession(String sessionId) {
    final timestamp = _sessionTimestamps[sessionId];
    if (timestamp == null) return false;

    final now = DateTime.now();
    return now.difference(timestamp) < _sessionTimeout;
  }

  /// Create a new session
  void createSession(String sessionId) {
    _sessionTimestamps[sessionId] = DateTime.now();
    _sessionEventIds[sessionId] = 0;
  }

  /// Update session timestamp
  void updateSession(String sessionId) {
    _sessionTimestamps[sessionId] = DateTime.now();
  }

  /// Add SSE session
  void addSseSession(
    String sessionId,
    StreamController<String> controller, {
    Map<String, String>? headers,
  }) {
    _activeSessions[sessionId] = controller;
    createSession(sessionId);
    if (headers != null) {
      _sessionHeaders[sessionId] = headers;
    }

    // Setup stream cleanup
    controller.onCancel = () {
      removeSseSession(sessionId);
    };
  }

  /// Add WebSocket session
  void addWebSocketSession(String sessionId, RelicWebSocket webSocket) {
    _activeWebSocketSessions[sessionId] = webSocket;
    createSession(sessionId);
  }

  /// Remove session metadata (timestamps and event IDs)
  void _removeSessionMetadata(String sessionId) {
    _sessionTimestamps.remove(sessionId);
    _sessionEventIds.remove(sessionId);
    _sessionHeaders.remove(sessionId);
  }

  /// Remove WebSocket session
  void removeWebSocketSession(String sessionId) {
    _activeWebSocketSessions.remove(sessionId);
    _removeSessionMetadata(sessionId);
  }

  /// Remove SSE session
  void removeSseSession(String sessionId) {
    _activeSessions.remove(sessionId);
    _removeSessionMetadata(sessionId);
  }

  /// Send an SSE event
  void sendSseEvent(
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
  int getNextEventId(String sessionId) {
    final currentId = _sessionEventIds[sessionId] ?? 0;
    final nextId = currentId + 1;
    _sessionEventIds[sessionId] = nextId;
    return nextId;
  }

  /// Clean up expired sessions
  void cleanupExpiredSessions() {
    final now = DateTime.now();
    final expiredSessions = _sessionTimestamps.entries
        .where((entry) => now.difference(entry.value) > _sessionTimeout)
        .map((entry) => entry.key)
        .toList();

    for (final sessionId in expiredSessions) {
      final controller = _activeSessions.remove(sessionId);
      _removeSessionMetadata(sessionId);

      if (controller != null && !controller.isClosed) {
        controller.close();
      }
    }

    if (expiredSessions.isNotEmpty) {
      _logger.info('Cleaned up ${expiredSessions.length} expired sessions');
    }
  }

  /// Close all sessions
  Future<void> closeAllSessions() async {
    final futures = _activeSessions.values
        .where((controller) => !controller.isClosed)
        .map((controller) => controller.close())
        .toList();

    if (futures.isNotEmpty) {
      await Future.wait(futures, eagerError: false);
      _logger.info('Closed ${futures.length} SSE sessions');
    }

    _activeSessions.clear();
    _sessionTimestamps.clear();
    _sessionEventIds.clear();
  }

  /// Close all WebSocket sessions
  Future<void> closeWebSocketSessions() async {
    final futures = _activeWebSocketSessions.values
        .map((webSocket) => webSocket.close())
        .toList();

    final sessionIds = _activeWebSocketSessions.keys.toList();
    _activeWebSocketSessions.clear();

    // Clean up metadata for WebSocket sessions only
    for (final sessionId in sessionIds) {
      if (!_activeSessions.containsKey(sessionId)) {
        _removeSessionMetadata(sessionId);
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures, eagerError: false);
      _logger.info('Closed ${futures.length} WebSocket sessions');
    }
  }

  /// Get active sessions count
  int get activeSessionsCount => _activeSessions.length;

  /// Get headers for a session
  Map<String, String>? getSessionHeaders(String sessionId) {
    return _sessionHeaders[sessionId];
  }

  /// Set headers for a session
  void setSessionHeaders(String sessionId, Map<String, String> headers) {
    _sessionHeaders[sessionId] = headers;
  }
}
