/// Basic "Hello World" MCP Server
///
/// This is the simplest possible MCP server demonstrating:
/// - Manual tool registration
/// - Basic request handling
/// - Both stdio and HTTP modes
library;

import 'package:logging/logging.dart';
import 'package:mcp_server_dart/mcp_server_dart.dart';

class HelloWorldMCP extends MCPServer {
  HelloWorldMCP()
    : super(
        name: 'hello-world-mcp',
        version: '1.0.0',
        description: 'A simple Hello World MCP server',
      );

  void registerHandlers() {
    registerTool(
      'greet',
      (context) async {
        final name = context.param<String>('name');
        return 'Hello, $name! Welcome to MCP Dart! 👋';
      },
      description: 'Greet someone by name',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the person to greet',
            'example': 'World',
          },
        },
        'required': ['name'],
      },
    );

    registerTool(
      'echo',
      (context) async {
        final message = context.param<String>('message');
        return 'Echo: $message';
      },
      description: 'Echo back a message',
      inputSchema: {
        'type': 'object',
        'properties': {
          'message': {'type': 'string', 'description': 'Message to echo back'},
        },
        'required': ['message'],
      },
    );
  }
}

void main(List<String> args) async {
  // Setup logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final server = HelloWorldMCP();
  server.registerHandlers();

  print('🌟 Hello World MCP Server');
  print('📋 Available tools: greet, echo');
  print('');

  // Handle command line arguments
  if (args.contains('--help') || args.contains('-h')) {
    print('Usage: dart hello_world.dart [options]');
    print('');
    print('Options:');
    print('  --stdio        Start server in stdio mode (default)');
    print('  --http         Start HTTP server on port 8080');
    print('  --port <port>  Specify HTTP port (default: 8080)');
    print('  --help, -h     Show this help message');
    return;
  }

  if (args.contains('--http')) {
    final port = args.contains('--port')
        ? int.parse(args[args.indexOf('--port') + 1])
        : 8080;

    print('🌐 Starting HTTP server on port $port...');
    print('🔍 Health check: http://localhost:$port/health');
    print('📊 Status: http://localhost:$port/status');
    print('');

    await server.serve(port: port);
  } else {
    print('🔌 Starting MCP server on stdio...');
    print('💡 Tip: Use --http flag to start HTTP server instead');
    print('');

    await server.start();
  }
}
