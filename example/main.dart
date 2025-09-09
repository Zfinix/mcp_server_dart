/// Example runner for the MCP servers
///
/// This runner allows you to start different MCP server examples:
/// - hello-world: Simple greeting and echo server
/// - calculator: Mathematical operations server
/// - weather: Weather service with mock data
/// - google-maps: Location and mapping services
library;

import 'dart:io';
import 'lib/basic/hello_world.dart' as hello_world;
import 'lib/basic/calculator.dart' as calculator;
import 'lib/advanced/weather_service.dart' as weather;
import 'lib/advanced/google_maps.dart' as google_maps;

Future<void> main(List<String> args) async {
  // Parse which example to run
  String? example;
  List<String> remainingArgs = [];

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--example' || args[i] == '-e') {
      if (i + 1 < args.length) {
        example = args[i + 1];
        i++; // Skip the next argument
      }
    } else {
      remainingArgs.add(args[i]);
    }
  }

  // Show help if requested or no example specified
  if (remainingArgs.contains('--help') ||
      remainingArgs.contains('-h') ||
      example == null) {
    _showHelp();
    return;
  }

  // Run the specified example
  switch (example.toLowerCase()) {
    case 'hello-world':
    case 'hello':
      print('🌟 Starting Hello World MCP Server...');
      hello_world.main(remainingArgs);
      break;

    case 'calculator':
    case 'calc':
      print('🧮 Starting Calculator MCP Server...');
      calculator.main(remainingArgs);
      break;

    case 'weather':
      print('🌤️  Starting Weather Service MCP Server...');
      weather.main(remainingArgs);
      break;

    case 'google-maps':
    case 'maps':
      print('🗺️  Starting Google Maps MCP Server...');
      google_maps.main();
      break;

    default:
      print('❌ Unknown example: $example');
      print('');
      _showHelp();
      exit(1);
  }
}

void _showHelp() {
  // Fallback to manual help if generated code isn't available yet
  print('Usage: dart main.dart --example <name> [options]');
  print('');
  print('Available examples:');
  print('  hello-world    Simple greeting and echo server');
  print('  calculator     Mathematical operations server');
  print('  weather        Weather service with mock data');
  print('  google-maps    Location and mapping services');
  print('');
  print('Options:');
  print('  --example, -e <name>  Specify which example to run');
  print('  --stdio              Start server in stdio mode (default)');
  print('  --http               Start HTTP server on port 8080');
  print('  --port <port>        Specify HTTP port (default: 8080)');
  print('  --help, -h           Show this help message');
  print('');
  print('Examples:');
  print('  dart main.dart --example hello-world');
  print('  dart main.dart -e calculator --http');
  print('  dart main.dart -e weather --http --port 3000');
}
