/// Middleware implementations for MCP server
library;

import 'package:logging/logging.dart';
import 'package:relic/relic.dart';

/// CORS middleware
Middleware corsMiddleware(bool enabled) {
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
Middleware loggingMiddleware(Logger logger) {
  return (Handler innerHandler) {
    return (NewContext context) async {
      final stopwatch = Stopwatch()..start();
      final request = context.request;

      logger.info('${request.method.value.toUpperCase()} ${request.url.path}');

      try {
        final result = await innerHandler(context);
        stopwatch.stop();

        if (result is ResponseContext) {
          logger.info(
            '${request.method.value.toUpperCase()} ${request.url.path} '
            '${result.response.statusCode} ${stopwatch.elapsedMilliseconds}ms',
          );
        }

        return result;
      } catch (e) {
        stopwatch.stop();
        logger.warning(
          '${request.method.value.toUpperCase()} ${request.url.path} '
          'ERROR ${stopwatch.elapsedMilliseconds}ms: $e',
        );
        rethrow;
      }
    };
  };
}

/// Error handling middleware
Middleware errorHandlingMiddleware(Logger logger) {
  return (Handler innerHandler) {
    return (NewContext context) async {
      try {
        return await innerHandler(context);
      } catch (e, stackTrace) {
        logger.severe('Unhandled error in request handler: $e', e, stackTrace);

        return context.respond(
          Response.internalServerError(
            body: Body.fromString('Internal server error'),
          ),
        );
      }
    };
  };
}
