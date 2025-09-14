import 'dart:convert';
import 'package:test/test.dart';
import 'package:mcp_server_dart/mcp_server_dart.dart';

/// Test implementation of MCPServer
class TestMCPServer extends MCPServer {
  TestMCPServer()
    : super(name: 'test-server', version: '1.0.0', description: 'Test server');

  /// Test tool that returns a greeting
  Future<String> greet(String name) async {
    return 'Hello, $name!';
  }

  /// Test resource that returns user data
  Future<MCPResourceContent> getUserData(String uri) async {
    return MCPResourceContent(
      uri: uri,
      name: 'user_data',
      mimeType: 'application/json',
      text: jsonEncode({'user': 'test', 'id': '123'}),
    );
  }

  /// Test prompt that returns a code review template
  String codeReviewPrompt(Map<String, dynamic> args) {
    final code = args['code'] ?? '';
    final language = args['language'] ?? 'unknown';
    return 'Please review this $language code: $code';
  }

  /// Setup test handlers
  void setupTestHandlers() {
    registerTool(
      'greet',
      (context) => greet(context.param<String>('name')),
      description: 'Greet someone by name',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Name to greet'},
        },
        'required': ['name'],
      },
    );

    registerResource(
      'user_data',
      getUserData,
      description: 'User data resource',
      mimeType: 'application/json',
    );

    registerPrompt(
      'code_review',
      codeReviewPrompt,
      description: 'Code review prompt template',
      arguments: [
        MCPPromptArgument(
          name: 'code',
          description: 'Code to review',
          required: true,
        ),
        MCPPromptArgument(
          name: 'language',
          description: 'Programming language',
          required: false,
        ),
      ],
    );
  }
}

void main() {
  group('MCPServer', () {
    late TestMCPServer server;

    setUp(() {
      server = TestMCPServer();
      server.setupTestHandlers();
    });

    group('Basic Properties', () {
      test('should have correct server info', () {
        expect(server.name, equals('test-server'));
        expect(server.version, equals('1.0.0'));
        expect(server.description, equals('Test server'));
      });
    });

    group('Initialize Request', () {
      test('should handle initialize request correctly', () async {
        final request = MCPRequest(
          method: 'initialize',
          id: '1',
          params: {
            'protocolVersion': '2025-06-18',
            'capabilities': {},
            'clientInfo': {'name': 'test-client', 'version': '1.0.0'},
          },
        );

        final response = await server.handleRequest(request);

        expect(response.id, equals('1'));
        expect(response.error, isNull);
        expect(response.result, isNotNull);

        final result = response.result as Map<String, dynamic>;
        expect(result['protocolVersion'], equals('2025-06-18'));
        expect(result['capabilities'], isNotNull);
        expect(result['serverInfo']['name'], equals('test-server'));
        expect(result['serverInfo']['version'], equals('1.0.0'));
        expect(result['serverInfo']['description'], equals('Test server'));
      });
    });

    group('Tools', () {
      test('should list registered tools', () async {
        final request = MCPRequest(method: 'tools/list', id: '2');
        final response = await server.handleRequest(request);

        expect(response.id, equals('2'));
        expect(response.error, isNull);

        final result = response.result as Map<String, dynamic>;
        final tools = result['tools'] as List<dynamic>;
        expect(tools.length, equals(1));

        final tool = tools.first as Map<String, dynamic>;
        expect(tool['name'], equals('greet'));
        expect(tool['description'], equals('Greet someone by name'));
        expect(tool['inputSchema'], isNotNull);
      });

      test('should call tool successfully', () async {
        final request = MCPRequest(
          method: 'tools/call',
          id: '3',
          params: {
            'name': 'greet',
            'arguments': {'name': 'World'},
          },
        );

        final response = await server.handleRequest(request);

        expect(response.id, equals('3'));
        expect(response.error, isNull);

        final result = response.result as Map<String, dynamic>;
        final content = result['content'] as List<dynamic>;
        expect(content.length, equals(1));

        final textContent = content.first as Map<String, dynamic>;
        expect(textContent['type'], equals('text'));
        expect(jsonDecode(textContent['text']), equals('Hello, World!'));
      });

      test('should return error for missing tool', () async {
        final request = MCPRequest(
          method: 'tools/call',
          id: '4',
          params: {'name': 'nonexistent', 'arguments': {}},
        );

        final response = await server.handleRequest(request);

        expect(response.id, equals('4'));
        expect(response.error, isNotNull);
        expect(response.error!.code, equals(-32601));
        expect(response.error!.message, contains('Tool not found'));
      });

      test('should return error for missing parameters', () async {
        final request = MCPRequest(
          method: 'tools/call',
          id: '5',
          params: {
            'name': 'greet',
            'arguments': {}, // Missing 'name' parameter
          },
        );

        final response = await server.handleRequest(request);

        expect(response.id, equals('5'));
        expect(response.error, isNotNull);
        expect(response.error!.code, equals(-32603));
        expect(response.error!.message, contains('Tool execution error'));
      });
    });

    group('Resources', () {
      test('should list registered resources', () async {
        final request = MCPRequest(method: 'resources/list', id: '6');
        final response = await server.handleRequest(request);

        expect(response.id, equals('6'));
        expect(response.error, isNull);

        final result = response.result as Map<String, dynamic>;
        final resources = result['resources'] as List<dynamic>;
        expect(resources.length, equals(1));

        final resource = resources.first as Map<String, dynamic>;
        expect(resource['name'], equals('user_data'));
        expect(resource['uri'], equals('mcp://user_data'));
        expect(resource['description'], equals('User data resource'));
        expect(resource['mimeType'], equals('application/json'));
      });

      test('should read resource successfully', () async {
        final request = MCPRequest(
          method: 'resources/read',
          id: '7',
          params: {'uri': 'mcp://user_data'},
        );

        final response = await server.handleRequest(request);

        expect(response.id, equals('7'));
        expect(response.error, isNull);

        final result = response.result as Map<String, dynamic>;
        final contents = result['contents'] as List<dynamic>;
        expect(contents.length, equals(1));

        final content = contents.first as Map<String, dynamic>;
        expect(content['uri'], equals('mcp://user_data'));
        expect(content['mimeType'], equals('application/json'));
        expect(
          jsonDecode(content['text']),
          equals({'user': 'test', 'id': '123'}),
        );
      });

      test('should return error for missing resource', () async {
        final request = MCPRequest(
          method: 'resources/read',
          id: '8',
          params: {'uri': 'mcp://nonexistent'},
        );

        final response = await server.handleRequest(request);

        expect(response.id, equals('8'));
        expect(response.error, isNotNull);
        expect(response.error!.code, equals(-32601));
        expect(response.error!.message, contains('Resource not found'));
      });
    });

    group('Prompts', () {
      test('should list registered prompts', () async {
        final request = MCPRequest(method: 'prompts/list', id: '9');
        final response = await server.handleRequest(request);

        expect(response.id, equals('9'));
        expect(response.error, isNull);

        final result = response.result as Map<String, dynamic>;
        final prompts = result['prompts'] as List<dynamic>;
        expect(prompts.length, equals(1));

        final prompt = prompts.first as Map<String, dynamic>;
        expect(prompt['name'], equals('code_review'));
        expect(prompt['description'], equals('Code review prompt template'));

        final arguments = prompt['arguments'] as List<dynamic>;
        expect(arguments.length, equals(2));
        expect(arguments[0]['name'], equals('code'));
        expect(arguments[0]['required'], isTrue);
        expect(arguments[1]['name'], equals('language'));
        expect(arguments[1]['required'], isFalse);
      });

      test('should get prompt successfully', () async {
        final request = MCPRequest(
          method: 'prompts/get',
          id: '10',
          params: {
            'name': 'code_review',
            'arguments': {'code': 'print("hello")', 'language': 'python'},
          },
        );

        final response = await server.handleRequest(request);

        expect(response.id, equals('10'));
        expect(response.error, isNull);

        final result = response.result as Map<String, dynamic>;
        expect(result['description'], equals('Code review prompt template'));

        final messages = result['messages'] as List<dynamic>;
        expect(messages.length, equals(1));

        final message = messages.first as Map<String, dynamic>;
        expect(message['role'], equals('user'));
        expect(message['content']['type'], equals('text'));
        expect(
          message['content']['text'],
          contains('python code: print("hello")'),
        );
      });

      test('should return error for missing prompt', () async {
        final request = MCPRequest(
          method: 'prompts/get',
          id: '11',
          params: {'name': 'nonexistent', 'arguments': {}},
        );

        final response = await server.handleRequest(request);

        expect(response.id, equals('11'));
        expect(response.error, isNotNull);
        expect(response.error!.code, equals(-32601));
        expect(response.error!.message, contains('Prompt not found'));
      });
    });

    group('Error Handling', () {
      test('should return method not found for unknown methods', () async {
        final request = MCPRequest(method: 'unknown/method', id: '12');
        final response = await server.handleRequest(request);

        expect(response.id, equals('12'));
        expect(response.error, isNotNull);
        expect(response.error!.code, equals(-32601));
        expect(response.error!.message, contains('Method not found'));
      });

      test('should handle missing parameters gracefully', () async {
        final request = MCPRequest(method: 'tools/call', id: '13');
        final response = await server.handleRequest(request);

        expect(response.id, equals('13'));
        expect(response.error, isNotNull);
        expect(response.error!.code, equals(-32602));
        expect(response.error!.message, contains('Missing parameters'));
      });
    });
  });
}
