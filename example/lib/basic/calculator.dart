/// Calculator MCP Server
///
/// Demonstrates:
/// - Multiple tools with different parameter types
/// - Input validation and error handling
/// - Mathematical operations
library;

import 'dart:math' as math;
import 'package:logging/logging.dart';
import 'package:dart_mcp/dart_mcp.dart';

class CalculatorMCP extends MCPServer {
  CalculatorMCP()
    : super(
        name: 'calculator-mcp',
        version: '1.0.0',
        description:
            'A calculator MCP server with basic and advanced operations',
      );

  void registerHandlers() {
    // Basic arithmetic
    registerTool(
      'add',
      (context) async {
        final a = context.param<num>('a');
        final b = context.param<num>('b');
        return {
          'operation': 'addition',
          'operands': [a, b],
          'result': a + b,
        };
      },
      description: 'Add two numbers',
      inputSchema: {
        'type': 'object',
        'properties': {
          'a': {'type': 'number', 'description': 'First number'},
          'b': {'type': 'number', 'description': 'Second number'},
        },
        'required': ['a', 'b'],
      },
    );

    registerTool(
      'subtract',
      (context) async {
        final a = context.param<num>('a');
        final b = context.param<num>('b');
        return {
          'operation': 'subtraction',
          'operands': [a, b],
          'result': a - b,
        };
      },
      description: 'Subtract two numbers',
      inputSchema: {
        'type': 'object',
        'properties': {
          'a': {'type': 'number', 'description': 'First number'},
          'b': {'type': 'number', 'description': 'Second number'},
        },
        'required': ['a', 'b'],
      },
    );

    registerTool(
      'multiply',
      (context) async {
        final a = context.param<num>('a');
        final b = context.param<num>('b');
        return {
          'operation': 'multiplication',
          'operands': [a, b],
          'result': a * b,
        };
      },
      description: 'Multiply two numbers',
      inputSchema: {
        'type': 'object',
        'properties': {
          'a': {'type': 'number', 'description': 'First number'},
          'b': {'type': 'number', 'description': 'Second number'},
        },
        'required': ['a', 'b'],
      },
    );

    registerTool(
      'divide',
      (context) async {
        final a = context.param<num>('a');
        final b = context.param<num>('b');

        if (b == 0) {
          throw ArgumentError('Division by zero is not allowed');
        }

        return {
          'operation': 'division',
          'operands': [a, b],
          'result': a / b,
        };
      },
      description: 'Divide two numbers',
      inputSchema: {
        'type': 'object',
        'properties': {
          'a': {'type': 'number', 'description': 'Dividend'},
          'b': {'type': 'number', 'description': 'Divisor (cannot be zero)'},
        },
        'required': ['a', 'b'],
      },
    );

    // Advanced operations
    registerTool(
      'power',
      (context) async {
        final base = context.param<num>('base');
        final exponent = context.param<num>('exponent');
        return {
          'operation': 'exponentiation',
          'base': base,
          'exponent': exponent,
          'result': math.pow(base, exponent),
        };
      },
      description: 'Raise a number to a power',
      inputSchema: {
        'type': 'object',
        'properties': {
          'base': {'type': 'number', 'description': 'Base number'},
          'exponent': {'type': 'number', 'description': 'Exponent'},
        },
        'required': ['base', 'exponent'],
      },
    );

    registerTool(
      'sqrt',
      (context) async {
        final number = context.param<num>('number');

        if (number < 0) {
          throw ArgumentError(
            'Cannot calculate square root of negative number',
          );
        }

        return {
          'operation': 'square_root',
          'operand': number,
          'result': math.sqrt(number),
        };
      },
      description: 'Calculate square root of a number',
      inputSchema: {
        'type': 'object',
        'properties': {
          'number': {
            'type': 'number',
            'description':
                'Number to calculate square root of (must be non-negative)',
            'minimum': 0,
          },
        },
        'required': ['number'],
      },
    );

    registerTool(
      'factorial',
      (context) async {
        final number = context.param<int>('number');

        if (number < 0) {
          throw ArgumentError('Factorial is not defined for negative numbers');
        }

        if (number > 20) {
          throw ArgumentError(
            'Factorial calculation limited to numbers <= 20 to prevent overflow',
          );
        }

        int result = 1;
        for (int i = 2; i <= number; i++) {
          result *= i;
        }

        return {'operation': 'factorial', 'operand': number, 'result': result};
      },
      description: 'Calculate factorial of a number',
      inputSchema: {
        'type': 'object',
        'properties': {
          'number': {
            'type': 'integer',
            'description': 'Non-negative integer (0-20)',
            'minimum': 0,
            'maximum': 20,
          },
        },
        'required': ['number'],
      },
    );

    // Statistics resource
    registerResource(
      'calculator_stats',
      (uri) async {
        return MCPResourceContent(
          uri: uri,
          name: 'calculator_stats',
          title: 'Calculator Statistics',
          description: 'Calculator server statistics and capabilities',
          mimeType: 'application/json',
          text: jsonEncode({
            'server': name,
            'version': version,
            'operations_supported': [
              'add',
              'subtract',
              'multiply',
              'divide',
              'power',
              'sqrt',
              'factorial',
            ],
            'features': {
              'basic_arithmetic': true,
              'advanced_math': true,
              'input_validation': true,
              'error_handling': true,
            },
            'limits': {'factorial_max': 20, 'sqrt_min': 0},
          }),
        );
      },
      description: 'Calculator server statistics and capabilities',
      mimeType: 'application/json',
    );
  }
}

void main(List<String> args) async {
  // Setup logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final server = CalculatorMCP();
  server.registerHandlers();

  print('🧮 Calculator MCP Server');
  print(
    '📋 Available tools: add, subtract, multiply, divide, power, sqrt, factorial',
  );
  print('📚 Available resources: calculator_stats');
  print('');

  // Handle command line arguments
  if (args.contains('--help') || args.contains('-h')) {
    print('Usage: dart calculator.dart [options]');
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
