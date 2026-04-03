import 'dart:async';

import 'package:logging/logging.dart';
import 'package:mcp_server_dart/mcp_server_dart.dart';

part 'modern_capabilities.mcp.dart';

final Logger _demoLogger = Logger('modern-capabilities-example.demo');

class ModernCapabilitiesServer extends MCPServer {
  ModernCapabilitiesServer()
    : super(
        name: 'modern-capabilities-example',
        version: '1.0.0',
        title: 'Modern Capabilities Example',
        description:
            'Demonstrates logging, completions, tasks, and richer initialize metadata.',
        instructions:
            'Try logging/setLevel, completion/complete for the classify prompt, and task-augmenting tools/call for the long_running_echo tool.',
        websiteUrl: 'https://example.com/mcp-server-dart',
        icons: const [
          MCPIcon(src: 'https://example.com/icon.png', mimeType: 'image/png'),
        ],
      ) {
    registerGeneratedHandlers();
  }

  @MCPCompletion('classify')
  Future<MCPCompletionResult> completeClassifyPrompt(
    MCPCompletionRequest request,
  ) async {
    final value = request.argument.value.toLowerCase();
    final suggestions = [
      'bug',
      'feature',
      'question',
      'research',
    ].where((item) => item.startsWith(value)).toList();
    return MCPCompletionResult(
      completion: MCPCompletionData(
        values: suggestions,
        total: suggestions.length,
        hasMore: false,
      ),
    );
  }

  @MCPTool(
    'log_demo',
    description:
        'Emit a few structured log notifications and return a summary.',
  )
  Future<String> logDemo(
    @MCPParam(description: 'Message to include in the logs') String message,
  ) async {
    _demoLogger.info(message);
    _demoLogger.warning('Halfway through the demo');
    return jsonEncode({'logged': true, 'message': message});
  }

  @MCPTool(
    'long_running_echo',
    description: 'Return text after a short delay. Works well with tasks.',
    annotations: {'taskSupport': 'optional'},
  )
  Future<String> longRunningEcho(
    @MCPParam(description: 'Text to echo back') String text,
    @MCPParam(description: 'Delay in milliseconds') int delayMs,
  ) async {
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    return jsonEncode({'echo': text, 'delayMs': delayMs});
  }

  @MCPResource(
    'example-status',
    description: 'High level server status information.',
  )
  Future<Map<String, dynamic>> exampleStatus() async {
    return {
      'name': name,
      'version': version,
      'loggingEnabled': supportsLogging,
      'completionsEnabled': supportsCompletions,
      'tasksEnabled': supportsTasks,
    };
  }

  @MCPPrompt(
    'classify',
    description: 'Classify an issue into a small set of categories.',
  )
  String classifyPrompt(
    @MCPParam(description: 'Issue category') String category,
    @MCPParam(description: 'Text to classify') String text,
  ) {
    return 'Classify the following text as $category:\n$text';
  }
}

Future<void> main(List<String> args) async {
  Logger.root.level = Level.INFO;

  final server = ModernCapabilitiesServer();
  server.attachLogger(Logger.root);

  if (args.contains('--http')) {
    await server.serve(port: 8080);
  } else {
    await server.start();
  }
}
