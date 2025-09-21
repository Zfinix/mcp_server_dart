import 'package:test/test.dart';
import 'package:mcp_server_dart/mcp_server_dart.dart';

void main() {
  group('MCPTool Annotation', () {
    test('should create tool annotation with name only', () {
      const kTool = tool('test_tool');

      expect(kTool.name, equals('test_tool'));
      expect(kTool.description, equals(''));
      expect(kTool.inputSchema, isNull);
    });

    test('should create tool annotation with description', () {
      const kTool = tool('test_tool', description: 'A test tool for testing');

      expect(kTool.name, equals('test_tool'));
      expect(kTool.description, equals('A test tool for testing'));
      expect(kTool.inputSchema, isNull);
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

      const kTool = tool(
        'user_tool',
        description: 'Manage user data',
        inputSchema: schema,
      );

      expect(kTool.name, equals('user_tool'));
      expect(kTool.description, equals('Manage user data'));
      expect(kTool.inputSchema, equals(schema));
    });

    test('should create tool annotation with all parameters', () {
      const schema = {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
        },
        'required': ['query'],
      };

      const kTool = tool(
        'search_tool',
        description: 'Search for information',
        inputSchema: schema,
      );

      expect(kTool.name, equals('search_tool'));
      expect(kTool.description, equals('Search for information'));
      expect(kTool.inputSchema, equals(schema));
    });
  });

  group('MCPResource Annotation', () {
    test('should create resource annotation with name only', () {
      const kResource = resource('test_resource');

      expect(kResource.name, equals('test_resource'));
      expect(kResource.description, equals(''));
      expect(kResource.mimeType, isNull);
    });

    test('should create resource annotation with description', () {
      const kResource = resource(
        'user_data',
        description: 'User profile information',
      );

      expect(kResource.name, equals('user_data'));
      expect(kResource.description, equals('User profile information'));
      expect(kResource.mimeType, isNull);
    });

    test('should create resource annotation with mime type', () {
      const kResource = resource(
        'config_file',
        description: 'Application configuration',
        mimeType: 'application/json',
      );

      expect(kResource.name, equals('config_file'));
      expect(kResource.description, equals('Application configuration'));
      expect(kResource.mimeType, equals('application/json'));
    });

    test('should create resource annotation with all parameters', () {
      const kResource = resource(
        'image_data',
        description: 'Profile image data',
        mimeType: 'image/png',
      );

      expect(kResource.name, equals('image_data'));
      expect(kResource.description, equals('Profile image data'));
      expect(kResource.mimeType, equals('image/png'));
    });
  });

  group('MCPPrompt Annotation', () {
    test('should create prompt annotation with name only', () {
      const kPrompt = prompt('test_prompt');

      expect(kPrompt.name, equals('test_prompt'));
      expect(kPrompt.description, equals(''));
      expect(kPrompt.arguments, isNull);
    });

    test('should create prompt annotation with description', () {
      const kPrompt = prompt(
        'code_review',
        description: 'Review code for best practices',
      );

      expect(kPrompt.name, equals('code_review'));
      expect(kPrompt.description, equals('Review code for best practices'));
      expect(kPrompt.arguments, isNull);
    });

    test('should create prompt annotation with arguments', () {
      const arguments = ['code', 'language'];
      const kPrompt = prompt(
        'code_review',
        description: 'Review code for best practices',
        arguments: arguments,
      );

      expect(kPrompt.name, equals('code_review'));
      expect(kPrompt.description, equals('Review code for best practices'));
      expect(kPrompt.arguments, equals(arguments));
    });

    test('should create prompt annotation with all parameters', () {
      const arguments = ['content', 'style', 'audience'];
      const kPrompt = prompt(
        'content_generator',
        description: 'Generate content based on parameters',
        arguments: arguments,
      );

      expect(kPrompt.name, equals('content_generator'));
      expect(
        kPrompt.description,
        equals('Generate content based on parameters'),
      );
      expect(kPrompt.arguments, equals(arguments));
    });
  });

  group('MCPParam Annotation', () {
    test('should create param annotation with defaults', () {
      const kParam = param();

      expect(kParam.required, isTrue);
      expect(kParam.description, equals(''));
      expect(kParam.type, isNull);
      expect(kParam.example, isNull);
    });

    test('should create param annotation with required false', () {
      const kParam = param(required: false);

      expect(kParam.required, isFalse);
      expect(kParam.description, equals(''));
      expect(kParam.type, isNull);
      expect(kParam.example, isNull);
    });

    test('should create param annotation with description', () {
      const kParam = param(description: 'The name of the user');

      expect(kParam.required, isTrue);
      expect(kParam.description, equals('The name of the user'));
      expect(kParam.type, isNull);
      expect(kParam.example, isNull);
    });

    test('should create param annotation with type', () {
      const kParam = param(description: 'User age', type: 'integer');

      expect(kParam.required, isTrue);
      expect(kParam.description, equals('User age'));
      expect(kParam.type, equals('integer'));
      expect(kParam.example, isNull);
    });

    test('should create param annotation with example', () {
      const kParam = param(
        description: 'User email address',
        type: 'string',
        example: 'user@example.com',
      );

      expect(kParam.required, isTrue);
      expect(kParam.description, equals('User email address'));
      expect(kParam.type, equals('string'));
      expect(kParam.example, equals('user@example.com'));
    });

    test('should create param annotation with all parameters', () {
      const kParam = param(
        required: false,
        description: 'Optional user nickname',
        type: 'string',
        example: 'johnny',
      );

      expect(kParam.required, isFalse);
      expect(kParam.description, equals('Optional user nickname'));
      expect(kParam.type, equals('string'));
      expect(kParam.example, equals('johnny'));
    });

    test('should create param annotation with complex example', () {
      const complexExample = {'name': 'John Doe', 'age': 30, 'active': true};

      const kParam = param(
        description: 'User object',
        type: 'object',
        example: complexExample,
      );

      expect(kParam.required, isTrue);
      expect(kParam.description, equals('User object'));
      expect(kParam.type, equals('object'));
      expect(kParam.example, equals(complexExample));
    });

    test('should create param annotation with list example', () {
      const listExample = ['admin', 'user', 'guest'];

      const kParam = param(
        description: 'User roles',
        type: 'array',
        example: listExample,
      );

      expect(kParam.required, isTrue);
      expect(kParam.description, equals('User roles'));
      expect(kParam.type, equals('array'));
      expect(kParam.example, equals(listExample));
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
