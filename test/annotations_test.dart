import 'package:test/test.dart';
import 'package:mcp_server_dart/mcp_server_dart.dart';

void main() {
  group('MCPTool Annotation', () {
    test('should create tool annotation with name only', () {
      const tool = tool('test_tool');

      expect(tool.name, equals('test_tool'));
      expect(tool.description, equals(''));
      expect(tool.inputSchema, isNull);
    });

    test('should create tool annotation with description', () {
      const tool = tool('test_tool', description: 'A test tool for testing');

      expect(tool.name, equals('test_tool'));
      expect(tool.description, equals('A test tool for testing'));
      expect(tool.inputSchema, isNull);
    });

    test('should create tool annotation with input schema', () {
      const schema = {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Name parameter'},
          'age': {'type': 'integer', 'description': 'Age parameter'},
        },
        'required': ['name'],
      };

      const tool = tool(
        'user_tool',
        description: 'Manage user data',
        inputSchema: schema,
      );

      expect(tool.name, equals('user_tool'));
      expect(tool.description, equals('Manage user data'));
      expect(tool.inputSchema, equals(schema));
    });

    test('should create tool annotation with all parameters', () {
      const schema = {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
        },
        'required': ['query'],
      };

      const tool = tool(
        'search_tool',
        description: 'Search for information',
        inputSchema: schema,
      );

      expect(tool.name, equals('search_tool'));
      expect(tool.description, equals('Search for information'));
      expect(tool.inputSchema, equals(schema));
    });
  });

  group('MCPResource Annotation', () {
    test('should create resource annotation with name only', () {
      const resource = resource('test_resource');

      expect(resource.name, equals('test_resource'));
      expect(resource.description, equals(''));
      expect(resource.mimeType, isNull);
    });

    test('should create resource annotation with description', () {
      const resource = resource(
        'user_data',
        description: 'User profile information',
      );

      expect(resource.name, equals('user_data'));
      expect(resource.description, equals('User profile information'));
      expect(resource.mimeType, isNull);
    });

    test('should create resource annotation with mime type', () {
      const resource = resource(
        'config_file',
        description: 'Application configuration',
        mimeType: 'application/json',
      );

      expect(resource.name, equals('config_file'));
      expect(resource.description, equals('Application configuration'));
      expect(resource.mimeType, equals('application/json'));
    });

    test('should create resource annotation with all parameters', () {
      const resource = resource(
        'image_data',
        description: 'Profile image data',
        mimeType: 'image/png',
      );

      expect(resource.name, equals('image_data'));
      expect(resource.description, equals('Profile image data'));
      expect(resource.mimeType, equals('image/png'));
    });
  });

  group('MCPPrompt Annotation', () {
    test('should create prompt annotation with name only', () {
      const prompt = prompt('test_prompt');

      expect(prompt.name, equals('test_prompt'));
      expect(prompt.description, equals(''));
      expect(prompt.arguments, isNull);
    });

    test('should create prompt annotation with description', () {
      const prompt = prompt(
        'code_review',
        description: 'Review code for best practices',
      );

      expect(prompt.name, equals('code_review'));
      expect(prompt.description, equals('Review code for best practices'));
      expect(prompt.arguments, isNull);
    });

    test('should create prompt annotation with arguments', () {
      const arguments = ['code', 'language'];
      const prompt = prompt(
        'code_review',
        description: 'Review code for best practices',
        arguments: arguments,
      );

      expect(prompt.name, equals('code_review'));
      expect(prompt.description, equals('Review code for best practices'));
      expect(prompt.arguments, equals(arguments));
    });

    test('should create prompt annotation with all parameters', () {
      const arguments = ['content', 'style', 'audience'];
      const prompt = prompt(
        'content_generator',
        description: 'Generate content based on parameters',
        arguments: arguments,
      );

      expect(prompt.name, equals('content_generator'));
      expect(
        prompt.description,
        equals('Generate content based on parameters'),
      );
      expect(prompt.arguments, equals(arguments));
    });
  });

  group('MCPParam Annotation', () {
    test('should create param annotation with defaults', () {
      const param = param();

      expect(param.required, isTrue);
      expect(param.description, equals(''));
      expect(param.type, isNull);
      expect(param.example, isNull);
    });

    test('should create param annotation with required false', () {
      const param = param(required: false);

      expect(param.required, isFalse);
      expect(param.description, equals(''));
      expect(param.type, isNull);
      expect(param.example, isNull);
    });

    test('should create param annotation with description', () {
      const param = param(description: 'The name of the user');

      expect(param.required, isTrue);
      expect(param.description, equals('The name of the user'));
      expect(param.type, isNull);
      expect(param.example, isNull);
    });

    test('should create param annotation with type', () {
      const param = param(description: 'User age', type: 'integer');

      expect(param.required, isTrue);
      expect(param.description, equals('User age'));
      expect(param.type, equals('integer'));
      expect(param.example, isNull);
    });

    test('should create param annotation with example', () {
      const param = param(
        description: 'User email address',
        type: 'string',
        example: 'user@example.com',
      );

      expect(param.required, isTrue);
      expect(param.description, equals('User email address'));
      expect(param.type, equals('string'));
      expect(param.example, equals('user@example.com'));
    });

    test('should create param annotation with all parameters', () {
      const param = param(
        required: false,
        description: 'Optional user nickname',
        type: 'string',
        example: 'johnny',
      );

      expect(param.required, isFalse);
      expect(param.description, equals('Optional user nickname'));
      expect(param.type, equals('string'));
      expect(param.example, equals('johnny'));
    });

    test('should create param annotation with complex example', () {
      const complexExample = {'name': 'John Doe', 'age': 30, 'active': true};

      const param = param(
        description: 'User object',
        type: 'object',
        example: complexExample,
      );

      expect(param.required, isTrue);
      expect(param.description, equals('User object'));
      expect(param.type, equals('object'));
      expect(param.example, equals(complexExample));
    });

    test('should create param annotation with list example', () {
      const listExample = ['admin', 'user', 'guest'];

      const param = param(
        description: 'User roles',
        type: 'array',
        example: listExample,
      );

      expect(param.required, isTrue);
      expect(param.description, equals('User roles'));
      expect(param.type, equals('array'));
      expect(param.example, equals(listExample));
    });
  });

  group('Annotation Integration', () {
    test('should work together in a realistic scenario', () {
      // Simulate how annotations would be used together
      const toolAnnotation = tool(
        'user_management',
        description: 'Manage user accounts',
        inputSchema: {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['create', 'update', 'delete'],
            },
            'user_data': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'email': {'type': 'string'},
                'age': {'type': 'integer'},
              },
              'required': ['name', 'email'],
            },
          },
          'required': ['action'],
        },
      );

      const resourceAnnotation = resource(
        'user_database',
        description: 'User database connection',
        mimeType: 'application/json',
      );

      const promptAnnotation = prompt(
        'user_welcome',
        description: 'Generate welcome message for new users',
        arguments: ['name', 'role'],
      );

      const paramAnnotation = param(
        required: true,
        description: 'User email address',
        type: 'string',
        example: 'user@example.com',
      );

      // Verify all annotations work as expected
      expect(toolAnnotation.name, equals('user_management'));
      expect(
        toolAnnotation.inputSchema!['properties']['action']['enum'],
        contains('create'),
      );

      expect(resourceAnnotation.name, equals('user_database'));
      expect(resourceAnnotation.mimeType, equals('application/json'));

      expect(promptAnnotation.name, equals('user_welcome'));
      expect(promptAnnotation.arguments, contains('name'));
      expect(promptAnnotation.arguments, contains('role'));

      expect(paramAnnotation.required, isTrue);
      expect(paramAnnotation.type, equals('string'));
      expect(paramAnnotation.example, equals('user@example.com'));
    });

    test('should handle edge cases gracefully', () {
      // Test with minimal configurations
      const minimalTool = tool('minimal');
      const minimalResource = resource('minimal');
      const minimalPrompt = prompt('minimal');
      const minimalParam = param();

      expect(minimalTool.name, equals('minimal'));
      expect(minimalTool.description, isEmpty);

      expect(minimalResource.name, equals('minimal'));
      expect(minimalResource.description, isEmpty);

      expect(minimalPrompt.name, equals('minimal'));
      expect(minimalPrompt.description, isEmpty);

      expect(minimalParam.required, isTrue);
      expect(minimalParam.description, isEmpty);
    });
  });
}
