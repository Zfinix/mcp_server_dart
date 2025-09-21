import 'dart:convert';
import 'package:test/test.dart';
import 'package:mcp_server_dart/mcp_server_dart.dart';

/// A real production-style MCP server using annotations
/// This tests the actual framework as it would be used in production
class ProductionMCPServer extends MCPServer {
  ProductionMCPServer()
    : super(
        name: 'production-test-server',
        version: '2.0.0',
        description: 'Production-style MCP server for testing',
      );

  /// Weather tool with proper annotations (simulated)
  @tool(
    'get_weather',
    description: 'Get current weather for a location',
    inputSchema: {
      'type': 'object',
      'properties': {
        'location': {
          'type': 'string',
          'description': 'City name or coordinates',
        },
        'units': {
          'type': 'string',
          'enum': ['celsius', 'fahrenheit'],
          'description': 'Temperature units',
        },
      },
      'required': ['location'],
    },
  )
  Future<Map<String, dynamic>> getWeather(
    @param(description: 'Location to get weather for') String location, {
    @param(
      required: false,
      description: 'Temperature units',
      example: 'celsius',
    )
    String units = 'celsius',
  }) async {
    // Simulate API call delay
    await Future.delayed(Duration(milliseconds: 50));

    // Mock weather data
    final temperature = units == 'celsius' ? 22 : 72;
    final unit = units == 'celsius' ? '°C' : '°F';

    return {
      'location': location,
      'temperature': temperature,
      'unit': unit,
      'condition': 'sunny',
      'humidity': 65,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// File operations tool
  @tool(
    'file_operations',
    description: 'Perform file operations like read, write, list',
    inputSchema: {
      'type': 'object',
      'properties': {
        'operation': {
          'type': 'string',
          'enum': ['read', 'write', 'list', 'delete'],
        },
        'path': {'type': 'string'},
        'content': {'type': 'string'},
      },
      'required': ['operation', 'path'],
    },
  )
  Future<Map<String, dynamic>> fileOperations(
    String operation,
    String path, {
    String? content,
  }) async {
    switch (operation.toLowerCase()) {
      case 'read':
        return {
          'operation': 'read',
          'path': path,
          'content': 'Mock file content for $path',
          'size': 1024,
        };
      case 'write':
        if (content == null) {
          throw ArgumentError('Content is required for write operation');
        }
        return {
          'operation': 'write',
          'path': path,
          'bytes_written': content.length,
          'success': true,
        };
      case 'list':
        return {
          'operation': 'list',
          'path': path,
          'files': ['file1.txt', 'file2.json', 'subdirectory/'],
          'count': 3,
        };
      case 'delete':
        return {'operation': 'delete', 'path': path, 'success': true};
      default:
        throw ArgumentError('Unknown operation: $operation');
    }
  }

  /// Database query tool
  @tool('database_query', description: 'Execute database queries')
  Future<List<Map<String, dynamic>>> databaseQuery(
    String query, {
    Map<String, dynamic>? parameters,
  }) async {
    // Simulate database delay
    await Future.delayed(Duration(milliseconds: 30));

    // Mock database results
    if (query.toLowerCase().contains('select')) {
      return [
        {'id': 1, 'name': 'John Doe', 'email': 'john@example.com'},
        {'id': 2, 'name': 'Jane Smith', 'email': 'jane@example.com'},
      ];
    } else if (query.toLowerCase().contains('insert')) {
      return [
        {'inserted_id': 3, 'affected_rows': 1},
      ];
    } else {
      return [
        {'affected_rows': 1},
      ];
    }
  }

  /// Configuration resource
  @resource(
    'app_config',
    description: 'Application configuration settings',
    mimeType: 'application/json',
  )
  Future<MCPResourceContent> getAppConfig(String uri) async {
    final config = {
      'app_name': 'Production Test App',
      'version': '2.0.0',
      'environment': 'test',
      'database': {'host': 'localhost', 'port': 5432, 'name': 'test_db'},
      'features': {
        'weather_api': true,
        'file_operations': true,
        'database_access': true,
      },
      'limits': {
        'max_file_size': 10485760, // 10MB
        'rate_limit': 1000,
        'timeout': 30000,
      },
    };

    return MCPResourceContent(
      uri: uri,
      name: 'app_config',
      mimeType: 'application/json',
      text: jsonEncode(config),
    );
  }

  /// System metrics resource
  @resource(
    'system_metrics',
    description: 'Current system performance metrics',
    mimeType: 'application/json',
  )
  Future<MCPResourceContent> getSystemMetrics(String uri) async {
    final metrics = {
      'timestamp': DateTime.now().toIso8601String(),
      'uptime': Duration(hours: 24, minutes: 30).inSeconds,
      'memory': {
        'used': 256 * 1024 * 1024, // 256MB
        'total': 1024 * 1024 * 1024, // 1GB
        'usage_percent': 25.0,
      },
      'cpu': {
        'usage_percent': 15.5,
        'load_average': [0.8, 0.9, 1.1],
      },
      'disk': {
        'used': 50 * 1024 * 1024 * 1024, // 50GB
        'total': 100 * 1024 * 1024 * 1024, // 100GB
        'usage_percent': 50.0,
      },
      'network': {
        'bytes_sent': 1024 * 1024 * 100, // 100MB
        'bytes_received': 1024 * 1024 * 500, // 500MB
        'connections': 25,
      },
    };

    return MCPResourceContent(
      uri: uri,
      name: 'system_metrics',
      mimeType: 'application/json',
      text: jsonEncode(metrics),
    );
  }

  /// Code generation prompt
  @prompt(
    'generate_code',
    description: 'Generate code based on specifications',
    arguments: ['language', 'description', 'style'],
  )
  String generateCodePrompt(Map<String, dynamic> args) {
    final language = args['language'] ?? 'python';
    final description = args['description'] ?? '';
    final style = args['style'] ?? 'clean';

    return '''Generate $style $language code that implements the following:

Description: $description

Requirements:
- Follow $language best practices and conventions
- Include proper error handling
- Add comprehensive documentation/comments
- Use $style coding style
- Include type hints where applicable
- Add unit tests if appropriate

Please provide:
1. The main implementation
2. Usage examples
3. Any necessary imports or dependencies
4. Brief explanation of the approach
''';
  }

  /// API documentation prompt
  @prompt(
    'api_documentation',
    description: 'Generate API documentation',
    arguments: ['endpoint', 'method', 'parameters', 'responses'],
  )
  String apiDocumentationPrompt(Map<String, dynamic> args) {
    final endpoint = args['endpoint'] ?? '/api/unknown';
    final method = args['method'] ?? 'GET';
    final parameters = args['parameters'] as List<dynamic>? ?? [];
    final responses = args['responses'] as List<dynamic>? ?? [];

    return '''Generate comprehensive API documentation for:

**Endpoint:** $method $endpoint

**Parameters:**
${parameters.map((p) => '- $p').join('\n')}

**Responses:**
${responses.map((r) => '- $r').join('\n')}

Please include:
1. Detailed description of what this endpoint does
2. Request/response examples with sample data
3. Error codes and their meanings
4. Authentication requirements
5. Rate limiting information
6. Usage examples in different programming languages
7. Common use cases and best practices
''';
  }

  /// Manual registration of handlers (simulating what code generation would do)
  void registerProductionHandlers() {
    // Tools
    registerTool(
      'get_weather',
      (context) => getWeather(
        context.param<String>('location'),
        units: context.optionalParam<String>('units') ?? 'celsius',
      ),
      description: 'Get current weather for a location',
      inputSchema: {
        'type': 'object',
        'properties': {
          'location': {
            'type': 'string',
            'description': 'City name or coordinates',
          },
          'units': {
            'type': 'string',
            'enum': ['celsius', 'fahrenheit'],
            'description': 'Temperature units',
          },
        },
        'required': ['location'],
      },
    );

    registerTool(
      'file_operations',
      (context) => fileOperations(
        context.param<String>('operation'),
        context.param<String>('path'),
        content: context.optionalParam<String>('content'),
      ),
      description: 'Perform file operations like read, write, list',
      inputSchema: {
        'type': 'object',
        'properties': {
          'operation': {
            'type': 'string',
            'enum': ['read', 'write', 'list', 'delete'],
          },
          'path': {'type': 'string'},
          'content': {'type': 'string'},
        },
        'required': ['operation', 'path'],
      },
    );

    registerTool(
      'database_query',
      (context) => databaseQuery(
        context.param<String>('query'),
        parameters: context.optionalParam<Map<String, dynamic>>('parameters'),
      ),
      description: 'Execute database queries',
    );

    // Resources
    registerResource(
      'app_config',
      getAppConfig,
      description: 'Application configuration settings',
      mimeType: 'application/json',
    );

    registerResource(
      'system_metrics',
      getSystemMetrics,
      description: 'Current system performance metrics',
      mimeType: 'application/json',
    );

    // Prompts
    registerPrompt(
      'generate_code',
      generateCodePrompt,
      description: 'Generate code based on specifications',
      arguments: [
        MCPPromptArgument(
          name: 'language',
          description: 'Programming language',
          required: true,
        ),
        MCPPromptArgument(
          name: 'description',
          description: 'What to implement',
          required: true,
        ),
        MCPPromptArgument(
          name: 'style',
          description: 'Coding style preference',
          required: false,
        ),
      ],
    );

    registerPrompt(
      'api_documentation',
      apiDocumentationPrompt,
      description: 'Generate API documentation',
      arguments: [
        MCPPromptArgument(
          name: 'endpoint',
          description: 'API endpoint path',
          required: true,
        ),
        MCPPromptArgument(
          name: 'method',
          description: 'HTTP method',
          required: true,
        ),
        MCPPromptArgument(
          name: 'parameters',
          description: 'Request parameters',
          required: false,
        ),
        MCPPromptArgument(
          name: 'responses',
          description: 'Response formats',
          required: false,
        ),
      ],
    );
  }
}

void main() {
  group('Production MCP Server Tests', () {
    late ProductionMCPServer server;

    setUp(() {
      server = ProductionMCPServer();
      server.registerProductionHandlers();
    });

    group('Server Configuration', () {
      test('should have proper server metadata', () {
        expect(server.name, equals('production-test-server'));
        expect(server.version, equals('2.0.0'));
        expect(
          server.description,
          equals('Production-style MCP server for testing'),
        );
      });

      test(
        'should handle initialization with production capabilities',
        () async {
          final request = MCPRequest(
            method: 'initialize',
            id: 'init_1',
            params: {
              'protocolVersion': '2025-06-18',
              'capabilities': {
                'tools': {'listChanged': true},
                'resources': {'subscribe': true},
                'prompts': {'listChanged': true},
              },
              'clientInfo': {'name': 'production-client', 'version': '1.0.0'},
            },
          );

          final response = await server.handleRequest(request);

          expect(response.result, isNotNull);
          expect(response.error, isNull);

          final result = response.result as Map<String, dynamic>;
          expect(result['protocolVersion'], equals('2025-06-18'));
          expect(
            result['serverInfo']['name'],
            equals('production-test-server'),
          );
          expect(result['capabilities']['tools'], isNotNull);
          expect(result['capabilities']['resources'], isNotNull);
          expect(result['capabilities']['prompts'], isNotNull);
        },
      );
    });

    group('Production Tool Tests', () {
      test('should handle weather API calls correctly', () async {
        final request = MCPRequest(
          method: 'tools/call',
          id: 'weather_1',
          params: {
            'name': 'get_weather',
            'arguments': {'location': 'San Francisco', 'units': 'fahrenheit'},
          },
        );

        final response = await server.handleRequest(request);

        expect(response.result, isNotNull);
        expect(response.error, isNull);

        final content = response.result['content'] as List<dynamic>;
        final weatherData = jsonDecode(content.first['text']);

        expect(weatherData['location'], equals('San Francisco'));
        expect(weatherData['temperature'], equals(72));
        expect(weatherData['unit'], equals('°F'));
        expect(weatherData['condition'], equals('sunny'));
        expect(weatherData['timestamp'], isNotNull);
      });

      test('should handle file operations with proper validation', () async {
        // Test read operation
        final readRequest = MCPRequest(
          method: 'tools/call',
          id: 'file_1',
          params: {
            'name': 'file_operations',
            'arguments': {'operation': 'read', 'path': '/etc/config.json'},
          },
        );

        final readResponse = await server.handleRequest(readRequest);
        expect(readResponse.result, isNotNull);

        final readContent = readResponse.result['content'] as List<dynamic>;
        final readData = jsonDecode(readContent.first['text']);
        expect(readData['operation'], equals('read'));
        expect(readData['path'], equals('/etc/config.json'));
        expect(readData['content'], contains('Mock file content'));

        // Test write operation with content
        final writeRequest = MCPRequest(
          method: 'tools/call',
          id: 'file_2',
          params: {
            'name': 'file_operations',
            'arguments': {
              'operation': 'write',
              'path': '/tmp/test.txt',
              'content': 'Hello, World!',
            },
          },
        );

        final writeResponse = await server.handleRequest(writeRequest);
        expect(writeResponse.result, isNotNull);

        final writeContent = writeResponse.result['content'] as List<dynamic>;
        final writeData = jsonDecode(writeContent.first['text']);
        expect(writeData['operation'], equals('write'));
        expect(writeData['bytes_written'], equals(13));
        expect(writeData['success'], isTrue);
      });

      test('should handle database queries with different types', () async {
        // Test SELECT query
        final selectRequest = MCPRequest(
          method: 'tools/call',
          id: 'db_1',
          params: {
            'name': 'database_query',
            'arguments': {'query': 'SELECT * FROM users WHERE active = true'},
          },
        );

        final selectResponse = await server.handleRequest(selectRequest);
        expect(selectResponse.result, isNotNull);

        final selectContent = selectResponse.result['content'] as List<dynamic>;
        final selectData = jsonDecode(selectContent.first['text']);
        expect(selectData, isList);
        expect(selectData.length, equals(2));
        expect(selectData.first['name'], equals('John Doe'));

        // Test INSERT query
        final insertRequest = MCPRequest(
          method: 'tools/call',
          id: 'db_2',
          params: {
            'name': 'database_query',
            'arguments': {
              'query': 'INSERT INTO users (name, email) VALUES (?, ?)',
              'parameters': {'name': 'New User', 'email': 'new@example.com'},
            },
          },
        );

        final insertResponse = await server.handleRequest(insertRequest);
        expect(insertResponse.result, isNotNull);

        final insertContent = insertResponse.result['content'] as List<dynamic>;
        final insertData = jsonDecode(insertContent.first['text']);
        expect(insertData.first['inserted_id'], equals(3));
      });

      test('should handle tool errors appropriately', () async {
        // Test invalid file operation
        final invalidRequest = MCPRequest(
          method: 'tools/call',
          id: 'error_1',
          params: {
            'name': 'file_operations',
            'arguments': {'operation': 'invalid_op', 'path': '/some/path'},
          },
        );

        final errorResponse = await server.handleRequest(invalidRequest);
        expect(errorResponse.error, isNotNull);
        expect(errorResponse.error!.code, equals(-32603));
        expect(errorResponse.error!.message, contains('Unknown operation'));

        // Test write without content
        final writeNoContentRequest = MCPRequest(
          method: 'tools/call',
          id: 'error_2',
          params: {
            'name': 'file_operations',
            'arguments': {
              'operation': 'write',
              'path': '/tmp/test.txt',
              // Missing content parameter
            },
          },
        );

        final writeErrorResponse = await server.handleRequest(
          writeNoContentRequest,
        );
        expect(writeErrorResponse.error, isNotNull);
        expect(
          writeErrorResponse.error!.message,
          contains('Content is required'),
        );
      });
    });

    group('Production Resource Tests', () {
      test('should serve application configuration', () async {
        final request = MCPRequest(
          method: 'resources/read',
          id: 'config_1',
          params: {'uri': 'mcp://app_config'},
        );

        final response = await server.handleRequest(request);
        expect(response.result, isNotNull);

        final contents = response.result['contents'] as List<dynamic>;
        final configContent = contents.first;
        expect(configContent['mimeType'], equals('application/json'));

        final config = jsonDecode(configContent['text']);
        expect(config['app_name'], equals('Production Test App'));
        expect(config['version'], equals('2.0.0'));
        expect(config['environment'], equals('test'));
        expect(config['database']['host'], equals('localhost'));
        expect(config['features']['weather_api'], isTrue);
        expect(config['limits']['max_file_size'], equals(10485760));
      });

      test('should serve system metrics', () async {
        final request = MCPRequest(
          method: 'resources/read',
          id: 'metrics_1',
          params: {'uri': 'mcp://system_metrics'},
        );

        final response = await server.handleRequest(request);
        expect(response.result, isNotNull);

        final contents = response.result['contents'] as List<dynamic>;
        final metricsContent = contents.first;
        expect(metricsContent['mimeType'], equals('application/json'));

        final metrics = jsonDecode(metricsContent['text']);
        expect(metrics['timestamp'], isNotNull);
        expect(metrics['uptime'], isA<int>());
        expect(metrics['memory']['usage_percent'], equals(25.0));
        expect(metrics['cpu']['usage_percent'], equals(15.5));
        expect(metrics['cpu']['load_average'], isList);
        expect(metrics['disk']['usage_percent'], equals(50.0));
        expect(metrics['network']['connections'], equals(25));
      });
    });

    group('Production Prompt Tests', () {
      test('should generate code prompts correctly', () async {
        final request = MCPRequest(
          method: 'prompts/get',
          id: 'prompt_1',
          params: {
            'name': 'generate_code',
            'arguments': {
              'language': 'rust',
              'description': 'HTTP client with retry logic',
              'style': 'functional',
            },
          },
        );

        final response = await server.handleRequest(request);
        expect(response.result, isNotNull);

        final messages = response.result['messages'] as List<dynamic>;
        final promptText = messages.first['content']['text'];

        expect(promptText, contains('functional rust code'));
        expect(promptText, contains('HTTP client with retry logic'));
        expect(promptText, contains('rust best practices'));
        expect(promptText, contains('error handling'));
        expect(promptText, contains('unit tests'));
      });

      test('should generate API documentation prompts', () async {
        final request = MCPRequest(
          method: 'prompts/get',
          id: 'prompt_2',
          params: {
            'name': 'api_documentation',
            'arguments': {
              'endpoint': '/api/v1/users',
              'method': 'POST',
              'parameters': ['name: string', 'email: string', 'role: enum'],
              'responses': [
                '201: User created',
                '400: Validation error',
                '409: Email exists',
              ],
            },
          },
        );

        final response = await server.handleRequest(request);
        expect(response.result, isNotNull);

        final messages = response.result['messages'] as List<dynamic>;
        final promptText = messages.first['content']['text'];

        expect(promptText, contains('POST /api/v1/users'));
        expect(promptText, contains('name: string'));
        expect(promptText, contains('201: User created'));
        expect(promptText, contains('Authentication requirements'));
        expect(promptText, contains('Usage examples'));
        expect(promptText, contains('programming languages'));
      });
    });

    group('Production Integration Tests', () {
      test('should handle complex workflow scenarios', () async {
        // 1. Initialize server
        final initResponse = await server.handleRequest(
          MCPRequest(
            method: 'initialize',
            id: '1',
            params: {'protocolVersion': '2025-06-18'},
          ),
        );
        expect(initResponse.result, isNotNull);

        // 2. List all capabilities
        final toolsResponse = await server.handleRequest(
          MCPRequest(method: 'tools/list', id: '2'),
        );
        final tools = toolsResponse.result['tools'] as List<dynamic>;
        expect(tools.length, equals(3));

        final resourcesResponse = await server.handleRequest(
          MCPRequest(method: 'resources/list', id: '3'),
        );
        final resources =
            resourcesResponse.result['resources'] as List<dynamic>;
        expect(resources.length, equals(2));

        final promptsResponse = await server.handleRequest(
          MCPRequest(method: 'prompts/list', id: '4'),
        );
        final prompts = promptsResponse.result['prompts'] as List<dynamic>;
        expect(prompts.length, equals(2));

        // 3. Execute a complex workflow
        // Get weather for deployment location
        final weatherResponse = await server.handleRequest(
          MCPRequest(
            method: 'tools/call',
            id: '5',
            params: {
              'name': 'get_weather',
              'arguments': {'location': 'Production Server Location'},
            },
          ),
        );
        expect(weatherResponse.result, isNotNull);

        // Read current config
        final configResponse = await server.handleRequest(
          MCPRequest(
            method: 'resources/read',
            id: '6',
            params: {'uri': 'mcp://app_config'},
          ),
        );
        expect(configResponse.result, isNotNull);

        // Check system metrics
        final metricsResponse = await server.handleRequest(
          MCPRequest(
            method: 'resources/read',
            id: '7',
            params: {'uri': 'mcp://system_metrics'},
          ),
        );
        expect(metricsResponse.result, isNotNull);

        // Generate deployment documentation
        final docPromptResponse = await server.handleRequest(
          MCPRequest(
            method: 'prompts/get',
            id: '8',
            params: {
              'name': 'api_documentation',
              'arguments': {'endpoint': '/api/deploy', 'method': 'POST'},
            },
          ),
        );
        expect(docPromptResponse.result, isNotNull);
      });

      test('should handle high load scenarios', () async {
        const requestCount = 50;
        final requests = <Future<MCPResponse>>[];

        // Create mixed workload
        for (int i = 0; i < requestCount; i++) {
          if (i % 3 == 0) {
            // Weather requests
            requests.add(
              server.handleRequest(
                MCPRequest(
                  method: 'tools/call',
                  id: 'load_$i',
                  params: {
                    'name': 'get_weather',
                    'arguments': {'location': 'City$i'},
                  },
                ),
              ),
            );
          } else if (i % 3 == 1) {
            // File operations
            requests.add(
              server.handleRequest(
                MCPRequest(
                  method: 'tools/call',
                  id: 'load_$i',
                  params: {
                    'name': 'file_operations',
                    'arguments': {'operation': 'list', 'path': '/data/batch$i'},
                  },
                ),
              ),
            );
          } else {
            // Database queries
            requests.add(
              server.handleRequest(
                MCPRequest(
                  method: 'tools/call',
                  id: 'load_$i',
                  params: {
                    'name': 'database_query',
                    'arguments': {'query': 'SELECT * FROM batch_$i LIMIT 10'},
                  },
                ),
              ),
            );
          }
        }

        final responses = await Future.wait(requests);

        // All requests should succeed
        for (int i = 0; i < responses.length; i++) {
          expect(responses[i].result, isNotNull, reason: 'Request $i failed');
          expect(responses[i].error, isNull, reason: 'Request $i had error');
        }
      });
    });

    group('Production Error Scenarios', () {
      test('should handle malformed requests gracefully', () async {
        final malformedRequest = MCPRequest(
          method: 'tools/call',
          id: 'malformed_1',
          params: {
            'name': 'get_weather',
            // Missing required arguments
          },
        );

        final response = await server.handleRequest(malformedRequest);
        expect(response.error, isNotNull);
        expect(response.error!.code, equals(-32603));
      });

      test('should handle resource not found errors', () async {
        final request = MCPRequest(
          method: 'resources/read',
          id: 'not_found_1',
          params: {'uri': 'mcp://nonexistent_resource'},
        );

        final response = await server.handleRequest(request);
        expect(response.error, isNotNull);
        expect(response.error!.code, equals(-32601));
        expect(response.error!.message, contains('Resource not found'));
      });

      test('should validate tool parameters properly', () async {
        final request = MCPRequest(
          method: 'tools/call',
          id: 'validation_1',
          params: {
            'name': 'file_operations',
            'arguments': {
              'operation': 'write',
              'path': '/tmp/test.txt',
              // Missing content for write operation
            },
          },
        );

        final response = await server.handleRequest(request);
        expect(response.error, isNotNull);
        expect(response.error!.message, contains('Content is required'));
      });
    });
  });
}
