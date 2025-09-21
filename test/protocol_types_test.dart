import 'package:test/test.dart';
import 'package:mcp_server_dart/mcp_server_dart.dart';

void main() {
  group('MCPRequest', () {
    test('should create request with required fields', () {
      final request = MCPRequest(method: 'test/method', id: '123');

      expect(request.method, equals('test/method'));
      expect(request.id, equals('123'));
      expect(request.jsonrpc, equals('2.0'));
      expect(request.params, isNull);
    });

    test('should create request with all fields', () {
      final params = {'param1': 'value1', 'param2': 42};
      final request = MCPRequest(
        method: 'test/method',
        id: '123',
        params: params,
        jsonrpc: '2.0',
      );

      expect(request.method, equals('test/method'));
      expect(request.id, equals('123'));
      expect(request.jsonrpc, equals('2.0'));
      expect(request.params, equals(params));
    });

    test('should serialize to JSON correctly', () {
      final params = {'param1': 'value1', 'param2': 42};
      final request = MCPRequest(
        method: 'test/method',
        id: '123',
        params: params,
      );

      final json = request.toJson();
      expect(json['jsonrpc'], equals('2.0'));
      expect(json['method'], equals('test/method'));
      expect(json['id'], equals('123'));
      expect(json['params'], equals(params));
    });

    test('should serialize to JSON without optional fields', () {
      final request = MCPRequest(method: 'test/method');

      final json = request.toJson();
      expect(json['jsonrpc'], equals('2.0'));
      expect(json['method'], equals('test/method'));
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('params'), isFalse);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'jsonrpc': '2.0',
        'method': 'test/method',
        'id': '123',
        'params': {'param1': 'value1', 'param2': 42},
      };

      final request = MCPRequest.fromJson(json);
      expect(request.jsonrpc, equals('2.0'));
      expect(request.method, equals('test/method'));
      expect(request.id, equals('123'));
      expect(request.params, equals({'param1': 'value1', 'param2': 42}));
    });

    test('should deserialize from minimal JSON', () {
      final json = {'method': 'test/method'};

      final request = MCPRequest.fromJson(json);
      expect(request.jsonrpc, equals('2.0'));
      expect(request.method, equals('test/method'));
      expect(request.id, isNull);
      expect(request.params, isNull);
    });
  });

  group('MCPResponse', () {
    test('should create response with result', () {
      final result = {'data': 'test'};
      final response = MCPResponse(id: '123', result: result);

      expect(response.id, equals('123'));
      expect(response.result, equals(result));
      expect(response.error, isNull);
      expect(response.jsonrpc, equals('2.0'));
    });

    test('should create response with error', () {
      final error = MCPError(code: -32601, message: 'Method not found');
      final response = MCPResponse(id: '123', error: error);

      expect(response.id, equals('123'));
      expect(response.result, isNull);
      expect(response.error, equals(error));
      expect(response.jsonrpc, equals('2.0'));
    });

    test('should serialize to JSON with result', () {
      final result = {'data': 'test'};
      final response = MCPResponse(id: '123', result: result);

      final json = response.toJson();
      expect(json['jsonrpc'], equals('2.0'));
      expect(json['id'], equals('123'));
      expect(json['result'], equals(result));
      expect(json.containsKey('error'), isFalse);
    });

    test('should serialize to JSON with error', () {
      final error = MCPError(code: -32601, message: 'Method not found');
      final response = MCPResponse(id: '123', error: error);

      final json = response.toJson();
      expect(json['jsonrpc'], equals('2.0'));
      expect(json['id'], equals('123'));
      expect(json['error'], equals(error.toJson()));
      expect(json.containsKey('result'), isFalse);
    });

    test('should deserialize from JSON with result', () {
      final json = {
        'jsonrpc': '2.0',
        'id': '123',
        'result': {'data': 'test'},
      };

      final response = MCPResponse.fromJson(json);
      expect(response.jsonrpc, equals('2.0'));
      expect(response.id, equals('123'));
      expect(response.result, equals({'data': 'test'}));
      expect(response.error, isNull);
    });

    test('should deserialize from JSON with error', () {
      final json = {
        'jsonrpc': '2.0',
        'id': '123',
        'error': {'code': -32601, 'message': 'Method not found'},
      };

      final response = MCPResponse.fromJson(json);
      expect(response.jsonrpc, equals('2.0'));
      expect(response.id, equals('123'));
      expect(response.result, isNull);
      expect(response.error, isNotNull);
      expect(response.error!.code, equals(-32601));
      expect(response.error!.message, equals('Method not found'));
    });
  });

  group('MCPError', () {
    test('should create error with required fields', () {
      final error = MCPError(code: -32601, message: 'Method not found');

      expect(error.code, equals(-32601));
      expect(error.message, equals('Method not found'));
      expect(error.data, isNull);
    });

    test('should create error with data', () {
      final data = {'details': 'Additional error information'};
      final error = MCPError(
        code: -32603,
        message: 'Internal error',
        data: data,
      );

      expect(error.code, equals(-32603));
      expect(error.message, equals('Internal error'));
      expect(error.data, equals(data));
    });

    test('should serialize to JSON correctly', () {
      final data = {'details': 'Additional error information'};
      final error = MCPError(
        code: -32603,
        message: 'Internal error',
        data: data,
      );

      final json = error.toJson();
      expect(json['code'], equals(-32603));
      expect(json['message'], equals('Internal error'));
      expect(json['data'], equals(data));
    });

    test('should serialize to JSON without data', () {
      final error = MCPError(code: -32601, message: 'Method not found');

      final json = error.toJson();
      expect(json['code'], equals(-32601));
      expect(json['message'], equals('Method not found'));
      expect(json.containsKey('data'), isFalse);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'code': -32603,
        'message': 'Internal error',
        'data': {'details': 'Additional error information'},
      };

      final error = MCPError.fromJson(json);
      expect(error.code, equals(-32603));
      expect(error.message, equals('Internal error'));
      expect(error.data, equals({'details': 'Additional error information'}));
    });
  });

  group('MCPToolDefinition', () {
    test('should create tool definition with required fields', () {
      final kTool = MCPToolDefinition(
        name: 'test_tool',
        description: 'A test tool',
      );

      expect(kTool.name, equals('test_tool'));
      expect(kTool.description, equals('A test tool'));
      expect(kTool.inputSchema, isNull);
    });

    test('should create tool definition with schema', () {
      final schema = {
        'type': 'object',
        'properties': {
          'param': {'type': 'string'},
        },
        'required': ['param'],
      };
      final kTool = MCPToolDefinition(
        name: 'test_tool',
        description: 'A test tool',
        inputSchema: schema,
      );

      expect(kTool.name, equals('test_tool'));
      expect(kTool.description, equals('A test tool'));
      expect(kTool.inputSchema, equals(schema));
    });

    test('should serialize to JSON correctly', () {
      final schema = {
        'type': 'object',
        'properties': {
          'param': {'type': 'string'},
        },
      };
      final tool = MCPToolDefinition(
        name: 'test_tool',
        description: 'A test tool',
        inputSchema: schema,
      );

      final json = tool.toJson();
      expect(json['name'], equals('test_tool'));
      expect(json['description'], equals('A test tool'));
      expect(json['inputSchema'], equals(schema));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'name': 'test_tool',
        'description': 'A test tool',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'param': {'type': 'string'},
          },
        },
      };

      final kTool = MCPToolDefinition.fromJson(json);
      expect(kTool.name, equals('test_tool'));
      expect(kTool.description, equals('A test tool'));
      expect(kTool.inputSchema, equals(json['inputSchema']));
    });
  });

  group('MCPResourceDefinition', () {
    test('should create resource definition with required fields', () {
      final kResource = MCPResourceDefinition(
        uri: 'mcp://test_resource',
        name: 'test_resource',
        description: 'A test resource',
      );

      expect(kResource.uri, equals('mcp://test_resource'));
      expect(kResource.name, equals('test_resource'));
      expect(kResource.description, equals('A test resource'));
      expect(kResource.mimeType, isNull);
    });

    test('should create resource definition with mime type', () {
      final kResource = MCPResourceDefinition(
        uri: 'mcp://test_resource',
        name: 'test_resource',
        description: 'A test resource',
        mimeType: 'application/json',
      );

      expect(kResource.uri, equals('mcp://test_resource'));
      expect(kResource.name, equals('test_resource'));
      expect(kResource.description, equals('A test resource'));
      expect(kResource.mimeType, equals('application/json'));
    });

    test('should serialize to JSON correctly', () {
      final resource = MCPResourceDefinition(
        uri: 'mcp://test_resource',
        name: 'test_resource',
        description: 'A test resource',
        mimeType: 'application/json',
      );

      final json = resource.toJson();
      expect(json['uri'], equals('mcp://test_resource'));
      expect(json['name'], equals('test_resource'));
      expect(json['description'], equals('A test resource'));
      expect(json['mimeType'], equals('application/json'));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'uri': 'mcp://test_resource',
        'name': 'test_resource',
        'description': 'A test resource',
        'mimeType': 'application/json',
      };

      final kResource = MCPResourceDefinition.fromJson(json);
      expect(kResource.uri, equals('mcp://test_resource'));
      expect(kResource.name, equals('test_resource'));
      expect(kResource.description, equals('A test resource'));
      expect(kResource.mimeType, equals('application/json'));
    });
  });

  group('MCPToolContext', () {
    test('should get required parameter correctly', () {
      final context = MCPToolContext(
        {'name': 'John', 'age': 30},
        'test_tool',
        '123',
      );

      expect(context.param<String>('name'), equals('John'));
      expect(context.param<int>('age'), equals(30));
      expect(context.toolName, equals('test_tool'));
      expect(context.requestId, equals('123'));
    });

    test('should get parameter with default value', () {
      final context = MCPToolContext({}, 'test_tool', '123');

      expect(
        context.param<String>('name', defaultValue: 'Default'),
        equals('Default'),
      );
      expect(context.param<int>('age', defaultValue: 0), equals(0));
    });

    test('should throw error for missing required parameter', () {
      final context = MCPToolContext({}, 'test_tool', '123');

      expect(
        () => context.param<String>('name'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Required parameter "name" is missing'),
          ),
        ),
      );
    });

    test('should throw error for wrong parameter type', () {
      final context = MCPToolContext({'name': 123}, 'test_tool', '123');

      expect(
        () => context.param<String>('name'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Parameter "name" expected type String but got int'),
          ),
        ),
      );
    });

    test('should get optional parameter correctly', () {
      final context = MCPToolContext(
        {'name': 'John', 'age': 30},
        'test_tool',
        '123',
      );

      expect(context.optionalParam<String>('name'), equals('John'));
      expect(context.optionalParam<String>('missing'), isNull);
      expect(
        context.optionalParam<int>('name'),
        isNull,
      ); // Wrong type returns null
    });

    test('should return all parameters', () {
      final params = {'name': 'John', 'age': 30, 'active': true};
      final context = MCPToolContext(params, 'test_tool', '123');

      final allParams = context.allParams;
      expect(allParams, equals(params));

      // Should return unmodifiable map
      expect(
        () => allParams['new'] = 'value',
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('MCPResourceContent', () {
    test('should create resource content with text', () {
      final content = MCPResourceContent(
        uri: 'mcp://test',
        name: 'test_resource',
        mimeType: 'text/plain',
        text: 'Hello, World!',
      );

      expect(content.uri, equals('mcp://test'));
      expect(content.name, equals('test_resource'));
      expect(content.mimeType, equals('text/plain'));
      expect(content.text, equals('Hello, World!'));
      expect(content.blob, isNull);
    });

    test('should create resource content with blob', () {
      final content = MCPResourceContent(
        uri: 'mcp://test',
        name: 'test_blob',
        mimeType: 'application/octet-stream',
        blob: 'base64encodeddata',
      );

      expect(content.uri, equals('mcp://test'));
      expect(content.name, equals('test_blob'));
      expect(content.mimeType, equals('application/octet-stream'));
      expect(content.text, isNull);
      expect(content.blob, equals('base64encodeddata'));
    });

    test('should serialize to JSON correctly', () {
      final content = MCPResourceContent(
        uri: 'mcp://test',
        name: 'test_json',
        mimeType: 'application/json',
        text: '{"key": "value"}',
      );

      final json = content.toJson();
      expect(json['uri'], equals('mcp://test'));
      expect(json['name'], equals('test_json'));
      expect(json['mimeType'], equals('application/json'));
      expect(json['text'], equals('{"key": "value"}'));
      expect(json.containsKey('blob'), isFalse);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'uri': 'mcp://test',
        'name': 'test_json',
        'mimeType': 'application/json',
        'text': '{"key": "value"}',
      };

      final content = MCPResourceContent.fromJson(json);
      expect(content.uri, equals('mcp://test'));
      expect(content.name, equals('test_json'));
      expect(content.mimeType, equals('application/json'));
      expect(content.text, equals('{"key": "value"}'));
      expect(content.blob, isNull);
    });
  });

  group('MCPPromptArgument', () {
    test('should create prompt argument with defaults', () {
      final arg = MCPPromptArgument(
        name: 'code',
        description: 'Code to review',
      );

      expect(arg.name, equals('code'));
      expect(arg.description, equals('Code to review'));
      expect(arg.required, isFalse);
    });

    test('should create required prompt argument', () {
      final arg = MCPPromptArgument(
        name: 'code',
        description: 'Code to review',
        required: true,
      );

      expect(arg.name, equals('code'));
      expect(arg.description, equals('Code to review'));
      expect(arg.required, isTrue);
    });

    test('should serialize to JSON correctly', () {
      final arg = MCPPromptArgument(
        name: 'code',
        description: 'Code to review',
        required: true,
      );

      final json = arg.toJson();
      expect(json['name'], equals('code'));
      expect(json['description'], equals('Code to review'));
      expect(json['required'], isTrue);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'name': 'code',
        'description': 'Code to review',
        'required': true,
      };

      final arg = MCPPromptArgument.fromJson(json);
      expect(arg.name, equals('code'));
      expect(arg.description, equals('Code to review'));
      expect(arg.required, isTrue);
    });
  });

  group('MCPPromptDefinition', () {
    test('should create prompt definition without arguments', () {
      final kPrompt = MCPPromptDefinition(
        name: 'test_prompt',
        description: 'A test prompt',
      );

      expect(kPrompt.name, equals('test_prompt'));
      expect(kPrompt.description, equals('A test prompt'));
      expect(kPrompt.arguments, isNull);
    });

    test('should create prompt definition with arguments', () {
      final arguments = [
        MCPPromptArgument(
          name: 'code',
          description: 'Code to review',
          required: true,
        ),
        MCPPromptArgument(
          name: 'language',
          description: 'Programming language',
        ),
      ];
      final kPrompt = MCPPromptDefinition(
        name: 'code_review',
        description: 'Review code for best practices',
        arguments: arguments,
      );

      expect(kPrompt.name, equals('code_review'));
      expect(kPrompt.description, equals('Review code for best practices'));
      expect(kPrompt.arguments, equals(arguments));
    });

    test('should serialize to JSON correctly', () {
      final arguments = [
        MCPPromptArgument(
          name: 'code',
          description: 'Code to review',
          required: true,
        ),
      ];
      final prompt = MCPPromptDefinition(
        name: 'code_review',
        description: 'Review code for best practices',
        arguments: arguments,
      );

      final json = prompt.toJson();
      expect(json['name'], equals('code_review'));
      expect(json['description'], equals('Review code for best practices'));
      expect(json['arguments'], isNotNull);

      final jsonArgs = json['arguments'] as List<dynamic>;
      expect(jsonArgs.length, equals(1));
      expect(jsonArgs[0]['name'], equals('code'));
      expect(jsonArgs[0]['required'], isTrue);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'name': 'code_review',
        'description': 'Review code for best practices',
        'arguments': [
          {'name': 'code', 'description': 'Code to review', 'required': true},
          {
            'name': 'language',
            'description': 'Programming language',
            'required': false,
          },
        ],
      };

      final kPrompt = MCPPromptDefinition.fromJson(json);
      expect(kPrompt.name, equals('code_review'));
      expect(kPrompt.description, equals('Review code for best practices'));
      expect(kPrompt.arguments, isNotNull);
      expect(kPrompt.arguments!.length, equals(2));
      expect(kPrompt.arguments![0].name, equals('code'));
      expect(kPrompt.arguments![0].required, isTrue);
      expect(kPrompt.arguments![1].name, equals('language'));
      expect(kPrompt.arguments![1].required, isFalse);
    });
  });
}
