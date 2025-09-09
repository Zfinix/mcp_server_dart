/// Utility functions for MCP server
library;

import 'dart:io';

/// Server utilities and helper functions
class ServerUtils {
  /// Validate origin header for security
  static bool isValidOrigin(
    String? origin, {
    required bool validateOrigins,
    required bool allowLocalhost,
    required List<String> allowedOrigins,
  }) {
    // If validation is disabled, allow all origins
    if (!validateOrigins) {
      return true;
    }

    origin ??= '';

    // If no origin and no specific origins configured, reject
    if (origin.isEmpty && allowedOrigins.isEmpty) {
      return false;
    }

    // For localhost development, allow localhost origins if enabled
    if (allowLocalhost &&
        (origin.startsWith('http://localhost') ||
            origin.startsWith('http://127.0.0.1'))) {
      return true;
    }

    // If specific origins are configured, check against them first
    if (allowedOrigins.isNotEmpty) {
      return allowedOrigins.any(
        (allowed) =>
            origin == allowed ||
            origin!.startsWith('$allowed/') ||
            (allowed.endsWith('*') &&
                origin.startsWith(allowed.substring(0, allowed.length - 1))),
      );
    }

    // If no specific origins configured, allow HTTPS origins in production (secure)
    if (origin.startsWith('https://')) {
      return true;
    }

    // Default: reject unknown origins
    return false;
  }

  /// Setup signal handlers for graceful shutdown
  static void setupSignalHandlers(Future<void> Function() onShutdown) {
    ProcessSignal.sigint.watch().listen((_) async {
      print('Received SIGINT, shutting down gracefully...');
      await onShutdown();
      exit(0);
    });

    ProcessSignal.sigterm.watch().listen((_) async {
      print('Received SIGTERM, shutting down gracefully...');
      await onShutdown();
      exit(0);
    });
  }
}
