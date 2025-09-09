/// Session management for MCP server
library;

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

/// Session manager for handling HTTP sessions and SSE connections
class SessionManager {
  final Logger _logger = Logger('SessionManager');

  /// Active SSE sessions
  final Map<String, StreamController<String>> _activeSessions = {};
  final Map<String, DateTime> _sessionTimestamps = {};
  final Map<String, int> _sessionEventIds = {};
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
  void addSseSession(String sessionId, StreamController<String> controller) {
    _activeSessions[sessionId] = controller;
    createSession(sessionId);

    // Setup stream cleanup
    controller.onCancel = () {
      removeSseSession(sessionId);
    };
  }

  /// Remove SSE session
  void removeSseSession(String sessionId) {
    _activeSessions.remove(sessionId);
    _sessionTimestamps.remove(sessionId);
    _sessionEventIds.remove(sessionId);
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

  /// Close all sessions
  Future<void> closeAllSessions() async {
    final futures = <Future>[];
    for (final controller in _activeSessions.values) {
      if (!controller.isClosed) {
        futures.add(controller.close());
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures, eagerError: false);
      _logger.info('Closed ${futures.length} SSE sessions');
    }

    _activeSessions.clear();
    _sessionTimestamps.clear();
    _sessionEventIds.clear();
  }

  /// Get active sessions count
  int get activeSessionsCount => _activeSessions.length;
}
