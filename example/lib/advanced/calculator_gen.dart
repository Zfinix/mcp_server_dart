/// Calculator MCP Server
///
/// Demonstrates:
/// - Multiple tools with different parameter types
/// - Input validation and error handling
/// - Mathematical operations
library;

import 'dart:math' as math;
import 'package:logging/logging.dart';
import 'package:mcp_server_dart/mcp_server_dart.dart';

part 'calculator_gen.g.dart';

class CalculatorMCP extends MCPServer {
  CalculatorMCP()
    : super(
        name: 'calculator-mcp',
        version: '1.0.0',
        description:
            'A calculator MCP server with basic and advanced operations',
      );

  @MCPTool('add', description: 'Add two numbers')
  Future<Map<String, dynamic>> add({required num a, required num b}) async {
    return {
      'operation': 'addition',
      'operands': [a, b],
      'result': a + b,
    };
  }

  @MCPTool('subtract', description: 'Subtract two numbers')
  Future<Map<String, dynamic>> subtract({
    required num a,
    required num b,
  }) async {
    return {
      'operation': 'subtraction',
      'operands': [a, b],
      'result': a - b,
    };
  }

  @MCPTool('multiply', description: 'Multiply two numbers')
  Future<Map<String, dynamic>> multiply({
    required num a,
    required num b,
  }) async {
    return {
      'operation': 'multiplication',
      'operands': [a, b],
      'result': a * b,
    };
  }

  @MCPTool('divide', description: 'Divide two numbers')
  Future<Map<String, dynamic>> divide({required num a, required num b}) async {
    if (b == 0) {
      throw ArgumentError('Division by zero is not allowed');
    }
    return {
      'operation': 'division',
      'operands': [a, b],
      'result': a / b,
    };
  }

  @MCPTool('power', description: 'Raise a number to a power')
  Future<Map<String, dynamic>> power({
    required num base,
    required num exponent,
  }) async {
    return {
      'operation': 'exponentiation',
      'base': base,
      'exponent': exponent,
      'result': math.pow(base, exponent),
    };
  }

  @MCPTool('sqrt', description: 'Calculate square root of a number')
  Future<Map<String, dynamic>> sqrt({required num number}) async {
    if (number < 0) {
      throw ArgumentError('Cannot calculate square root of negative number');
    }

    return {
      'operation': 'square_root',
      'operand': number,
      'result': math.sqrt(number),
    };
  }

  @MCPTool('factorial', description: 'Calculate factorial of a number')
  Future<Map<String, dynamic>> factorial({required int number}) async {
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
  }

  @MCPResource(
    'calculator_stats',
    description: 'Calculator server statistics and capabilities',
    mimeType: 'application/json',
  )
  Future<MCPResourceContent> calculatorStats(String uri) async {
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
  }
}

void main(List<String> args) async {
  // Enable verbose logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      print('Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('Stack trace: ${record.stackTrace}');
    }
  });

  final server = CalculatorMCP();
  server.showUsage();
  await server.serve(port: 8080);
  await server.stdio();
}
