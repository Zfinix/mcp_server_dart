/// Middleware implementations for MCP server
library;

import 'package:logging/logging.dart';
import 'package:relic/relic.dart' hide Logger;

/// Callback type for token validation
typedef TokenValidator = Future<bool> Function(String token);

/// CORS middleware
Middleware corsMiddleware(bool enabled) {
  return (Handler innerHandler) {
    return (final request) async {
      if (!enabled) return await innerHandler(request);

      // Handle preflight requests
      if (request.method == Method.options) {
        return Response.ok(
          headers: Headers.fromMap({
            'Access-Control-Allow-Origin': ['*'],
            'Access-Control-Allow-Methods': ['GET, POST, OPTIONS'],
            'Access-Control-Allow-Headers': ['Content-Type, Authorization'],
            'Access-Control-Max-Age': ['86400'],
          }),
        );
      }

      // Process request and add CORS headers to response
      final result = await innerHandler(request);
      if (result is Response) {
        return result.copyWith(
          headers: Headers.fromMap({
            'Access-Control-Allow-Origin': ['*'],
          }),
        );
      }

      return result;
    };
  };
}

/// Error handling middleware
Middleware errorHandlingMiddleware(Logger logger) {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } catch (e, stackTrace) {
        logger.severe('Unhandled error in request handler: $e', e, stackTrace);

        return Response.internalServerError(
          body: Body.fromString('Internal server error'),
        );
      }
    };
  };
}

/// Authentication middleware that validates Bearer tokens
Middleware authMiddleware({
  required bool enabled,
  required TokenValidator validateToken,
  List<String> publicPaths = const ['/health', '/status'],
}) {
  return (Handler innerHandler) {
    return (final request) async {
      // Skip authentication if disabled or for public paths
      if (!enabled || publicPaths.any(request.url.path.endsWith)) {
        return innerHandler(request);
      }

      // Check for Authorization header
      final authHeader = request.headers['authorization']?.firstOrNull;
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.unauthorized(
          body: Body.fromString('Missing or invalid Authorization header'),
          headers: Headers.fromMap({
            'www-authenticate': ['Bearer realm="mcp", error="invalid_token"'],
          }),
        );
      }

      // Extract and validate token
      final token = authHeader.substring(7).trim();
      final isValid = await validateToken(token);

      if (!isValid) {
        return Response.unauthorized(
          body: Body.fromString('Invalid or expired token'),
          headers: Headers.fromMap({
            'www-authenticate': ['Bearer realm="mcp", error="invalid_token"'],
          }),
        );
      }

      // Token is valid, proceed with the request
      return innerHandler(request);
    };
  };
}

/// Default token validator that accepts any non-empty token
Future<bool> defaultTokenValidator(String token) async {
  return token.isNotEmpty;
}
