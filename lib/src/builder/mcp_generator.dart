// ignore_for_file: avoid_types_as_parameter_names

import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:logging/logging.dart';
import 'package:mcp_server_dart/src/annotations.dart';
import 'package:source_gen/source_gen.dart';

import 'template_engine.dart';

/// Builder function for build.yaml
Builder mcpBuilder(BuilderOptions options) =>
    LibraryBuilder(MCPGenerator(), generatedExtension: '.mcp.dart');

/// Simple generator that processes all methods in MCP classes
class MCPGenerator extends Generator {
  static final _logger = Logger('MCPGenerator');

  // Type checkers for MCP annotations
  static const _mcpToolChecker = TypeChecker.typeNamed(tool);
  static const _mcpResourceChecker = TypeChecker.typeNamed(resource);
  static const _mcpPromptChecker = TypeChecker.typeNamed(prompt);
  static const _mcpParamChecker = TypeChecker.typeNamed(param);

  @override
  FutureOr<String?> generate(LibraryReader library, BuildStep buildStep) {
    final sourceFile = buildStep.inputId.path.split('/').last;
    final buffer = StringBuffer();

    // Check if this library has any MCP annotations at all
    bool hasAnyMCPAnnotations = false;

    // Process all classes in the library
    for (final element in library.allElements) {
      if (element is ClassElement) {
        final className = element.name;

        if (className != null) {
          // Find methods that have MCP annotations
          final annotatedMethods = element.methods
              .where(
                (m) =>
                    m.name != null &&
                    !m.isPrivate &&
                    !m.name!.startsWith('_') &&
                    m.name != 'registerGeneratedHandlers' &&
                    _hasAnyMCPAnnotation(m),
              )
              .toList();

          // Only generate code if there are annotated methods
          if (annotatedMethods.isNotEmpty) {
            hasAnyMCPAnnotations = true;
            buffer.writeln(
              _generateExtension(className, annotatedMethods, sourceFile),
            );
          }
        }
      }
    }

    // Only return generated code if we actually found MCP annotations
    if (!hasAnyMCPAnnotations) return null;

    // Format the generated code with dart_style
    final formatter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    );
    try {
      return formatter.format(buffer.toString());
    } catch (e) {
      // If formatting fails, return unformatted code
      _logger.warning('Failed to format generated code: $e');
      return buffer.toString();
    }
  }

  String _generateExtension(
    String className,
    List<MethodElement> methods,
    String sourceFile,
  ) {
    // Generate handler registrations
    final handlerRegistrations = methods
        .map((method) {
          return _generateHandlerRegistration(method);
        })
        .join('\n\n');

    // Generate usage capabilities
    final availableTools = methods
        .where((m) => _getAnnotationType(m) == 'MCPTool')
        .map((m) => _getAnnotationName(m))
        .toList();
    final availableResources = methods
        .where((m) => _getAnnotationType(m) == 'MCPResource')
        .map((m) => _getAnnotationName(m))
        .toList();
    final availablePrompts = methods
        .where((m) => _getAnnotationType(m) == 'MCPPrompt')
        .map((m) => _getAnnotationName(m))
        .toList();

    final usageCapabilities = _generateUsageCapabilities(
      availableTools,
      availableResources,
      availablePrompts,
    );

    // Use template engine to generate the final code
    return TemplateEngine.renderTemplateFromString(
      TemplateEngine.baseClassTemplate,
      {
        'sourceFile': sourceFile,
        'className': className,
        'handlerRegistrations': handlerRegistrations,
        'usageCapabilities': usageCapabilities,
      },
    );
  }

  /// Generate handler registration for a single method
  String _generateHandlerRegistration(MethodElement method) {
    final annotationType = _getAnnotationType(method);
    final annotationName = _getAnnotationName(method);
    final annotationDescription = _getAnnotationDescription(method);
    final methodName = method.name!;
    final methodDoc = method.documentationComment;

    // Generate method documentation comment
    String methodDocComment = '';
    if (methodDoc != null) {
      final cleanDoc = methodDoc
          .replaceAll('///', '')
          .replaceAll('//', '')
          .trim();
      if (cleanDoc.isNotEmpty) {
        methodDocComment = '    // $cleanDoc';
      }
    }

    // Generate parameter extractions and return statement based on type
    String parameterExtractions = '';
    String returnStatement = '';

    if (annotationType == 'MCPTool') {
      // Generate parameter extractions for tools
      final extractions = method.formalParameters
          .map((param) {
            final paramName = param.name;
            if (paramName == null) return '';

            final paramType = _getTypeString(param.type);
            if (param.isOptional) {
              final defaultValue = param.defaultValueCode ?? 'null';
              // For nullable types, don't add ?? null as it's redundant
              if (paramType.endsWith('?') && defaultValue == 'null') {
                return '        final $paramName = context.optionalParam<$paramType>(\'$paramName\');';
              } else {
                return '        final $paramName = context.optionalParam<$paramType>(\'$paramName\') ?? $defaultValue;';
              }
            } else {
              return '        final $paramName = context.param<$paramType>(\'$paramName\');';
            }
          })
          .where((s) => s.isNotEmpty)
          .join('\n');
      parameterExtractions = extractions;

      // Generate method call
      final positionalArgs = method.formalParameters
          .where((p) => p.isRequiredPositional && p.name != null)
          .map((p) => p.name!)
          .join(', ');
      final namedArgs = method.formalParameters
          .where((p) => p.isNamed && p.name != null)
          .map((p) => '${p.name}: ${p.name}')
          .join(', ');

      final args = [
        if (positionalArgs.isNotEmpty) positionalArgs,
        if (namedArgs.isNotEmpty) namedArgs,
      ].join(', ');

      if (method.returnType.toString().contains('Future')) {
        returnStatement = 'return await $methodName($args)';
      } else {
        returnStatement = 'return $methodName($args)';
      }

      // Generate input schema
      String inputSchemaStr = '';
      final inputSchema = _generateInputSchema(method);
      if (inputSchema != null) {
        inputSchemaStr = '      inputSchema: $inputSchema,';
      }

      return TemplateEngine.renderTemplateFromString(
        TemplateEngine.toolHandlerTemplate,
        {
          'annotationName': annotationName,
          'methodDoc': methodDocComment,
          'parameterExtractions': parameterExtractions,
          'returnStatement': returnStatement,
          'description': annotationDescription.isNotEmpty
              ? annotationDescription
              : 'Generated handler for $methodName',
          'inputSchema': inputSchemaStr,
        },
      );
    } else if (annotationType == 'MCPResource') {
      // For resources, check if method expects uri parameter
      final expectsUri =
          method.formalParameters.isNotEmpty &&
          method.formalParameters.any((p) => p.name == 'uri');

      if (expectsUri) {
        if (method.returnType.toString().contains('Future')) {
          returnStatement = 'return await $methodName(uri)';
        } else {
          returnStatement = 'return $methodName(uri)';
        }
      } else {
        // Method doesn't expect uri parameter, call without it
        if (method.returnType.toString().contains('Future')) {
          returnStatement =
              '''final result = await $methodName();
        return MCPResourceContent(
          uri: uri,
          name: '$annotationName',
          mimeType: 'application/json',
          text: jsonEncode(result),
        )''';
        } else {
          returnStatement =
              '''final result = $methodName();
        return MCPResourceContent(
          uri: uri,
          name: '$annotationName',
          mimeType: 'application/json',
          text: jsonEncode(result),
        )''';
        }
      }

      return TemplateEngine.renderTemplateFromString(
        TemplateEngine.resourceHandlerTemplate,
        {
          'annotationName': annotationName,
          'methodDoc': methodDocComment,
          'returnStatement': returnStatement,
        },
      );
    } else if (annotationType == 'MCPPrompt') {
      // For prompts, check if method takes Map<String, dynamic> directly
      final hasMapParameter =
          method.formalParameters.length == 1 &&
          method.formalParameters.first.type.toString().contains(
            'Map<String, dynamic>',
          );

      if (hasMapParameter) {
        returnStatement = 'return $methodName(args)';
      } else {
        // Extract individual parameters from args Map
        final extractions = method.formalParameters
            .map((param) {
              final paramName = param.name;
              if (paramName == null) return '';

              final paramType = _getTypeString(param.type);
              if (param.isOptional) {
                final defaultValue = param.defaultValueCode ?? 'null';
                // For nullable types, don't add ?? null as it's redundant
                if (paramType.endsWith('?') && defaultValue == 'null') {
                  return '        final $paramName = args[\'$paramName\'] as $paramType;';
                } else {
                  return '        final $paramName = args[\'$paramName\'] as $paramType? ?? $defaultValue;';
                }
              } else {
                return '        final $paramName = args[\'$paramName\'] as $paramType;';
              }
            })
            .where((s) => s.isNotEmpty)
            .join('\n');
        parameterExtractions = extractions;

        // Generate method call
        final positionalArgs = method.formalParameters
            .where((p) => p.isRequiredPositional && p.name != null)
            .map((p) => p.name!)
            .join(', ');
        final namedArgs = method.formalParameters
            .where((p) => p.isNamed && p.name != null)
            .map((p) => '${p.name}: ${p.name}')
            .join(', ');

        final args = [
          if (positionalArgs.isNotEmpty) positionalArgs,
          if (namedArgs.isNotEmpty) namedArgs,
        ].join(', ');

        returnStatement = 'return $methodName($args)';
      }

      return TemplateEngine.renderTemplateFromString(
        TemplateEngine.promptHandlerTemplate,
        {
          'annotationName': annotationName,
          'methodDoc': methodDocComment,
          'parameterExtractions': parameterExtractions,
          'returnStatement': returnStatement,
        },
      );
    }

    return '';
  }

  /// Generate usage capabilities section
  String _generateUsageCapabilities(
    List<String> availableTools,
    List<String> availableResources,
    List<String> availablePrompts,
  ) {
    final buffer = StringBuffer();

    if (availableTools.isNotEmpty) {
      buffer.writeln(
        '    print(\'Available tools: ${availableTools.join(", ")}\');',
      );
    }
    if (availableResources.isNotEmpty) {
      buffer.writeln(
        '    print(\'Available resources: ${availableResources.join(", ")}\');',
      );
    }
    if (availablePrompts.isNotEmpty) {
      buffer.writeln(
        '    print(\'Available prompts: ${availablePrompts.join(", ")}\');',
      );
    }

    if (availableTools.isNotEmpty ||
        availableResources.isNotEmpty ||
        availablePrompts.isNotEmpty) {
      buffer.writeln('    print(\'\');');
    }

    return buffer.toString();
  }

  /// Get string representation of Dart type for generic type parameters
  String _getTypeString(DartType type) {
    if (type.isDartAsyncFuture) {
      final futureType = type as InterfaceType;
      if (futureType.typeArguments.isNotEmpty) {
        return _getTypeString(futureType.typeArguments.first);
      }
    }

    // Simply use the display string which already includes nullability
    return type.getDisplayString();
  }

  /// Check if a method has any MCP annotation
  bool _hasAnyMCPAnnotation(MethodElement method) {
    // Use the type checkers to properly detect MCP annotations
    return _mcpToolChecker.hasAnnotationOfExact(method) ||
        _mcpResourceChecker.hasAnnotationOfExact(method) ||
        _mcpPromptChecker.hasAnnotationOfExact(method);
  }

  /// Get the annotation type for a method
  String _getAnnotationType(MethodElement method) {
    if (_mcpToolChecker.hasAnnotationOfExact(method)) {
      return 'MCPTool';
    } else if (_mcpResourceChecker.hasAnnotationOfExact(method)) {
      return 'MCPResource';
    } else if (_mcpPromptChecker.hasAnnotationOfExact(method)) {
      return 'MCPPrompt';
    }
    return 'MCPTool'; // Default fallback
  }

  /// Extract the name from the annotation
  String _getAnnotationName(MethodElement method) {
    // Try to get the name from the annotation, fallback to method name
    if (_mcpToolChecker.hasAnnotationOfExact(method)) {
      final annotation = _mcpToolChecker.firstAnnotationOfExact(method);
      if (annotation != null) {
        final nameValue = annotation.getField('name');
        if (nameValue != null && nameValue.toStringValue() != null) {
          return nameValue.toStringValue()!;
        }
      }
    } else if (_mcpResourceChecker.hasAnnotationOfExact(method)) {
      final annotation = _mcpResourceChecker.firstAnnotationOfExact(method);
      if (annotation != null) {
        final nameValue = annotation.getField('name');
        if (nameValue != null && nameValue.toStringValue() != null) {
          return nameValue.toStringValue()!;
        }
      }
    } else if (_mcpPromptChecker.hasAnnotationOfExact(method)) {
      final annotation = _mcpPromptChecker.firstAnnotationOfExact(method);
      if (annotation != null) {
        final nameValue = annotation.getField('name');
        if (nameValue != null && nameValue.toStringValue() != null) {
          return nameValue.toStringValue()!;
        }
      }
    }

    return method.name!;
  }

  /// Extract the description from the annotation
  String _getAnnotationDescription(MethodElement method) {
    if (_mcpToolChecker.hasAnnotationOfExact(method)) {
      final annotation = _mcpToolChecker.firstAnnotationOfExact(method);
      if (annotation != null) {
        final descValue = annotation.getField('description');
        if (descValue != null && descValue.toStringValue() != null) {
          return descValue.toStringValue()!;
        }
      }
    } else if (_mcpResourceChecker.hasAnnotationOfExact(method)) {
      final annotation = _mcpResourceChecker.firstAnnotationOfExact(method);
      if (annotation != null) {
        final descValue = annotation.getField('description');
        if (descValue != null && descValue.toStringValue() != null) {
          return descValue.toStringValue()!;
        }
      }
    } else if (_mcpPromptChecker.hasAnnotationOfExact(method)) {
      final annotation = _mcpPromptChecker.firstAnnotationOfExact(method);
      if (annotation != null) {
        final descValue = annotation.getField('description');
        if (descValue != null && descValue.toStringValue() != null) {
          return descValue.toStringValue()!;
        }
      }
    }

    return '';
  }

  /// Extract MCPParam annotation data from a parameter
  Map<String, dynamic>? _extractMCPParamData(dynamic param) {
    if (!_mcpParamChecker.hasAnnotationOfExact(param)) {
      return null;
    }

    final annotation = _mcpParamChecker.firstAnnotationOfExact(param);
    if (annotation == null) return null;

    final data = <String, dynamic>{};

    // Extract description
    final descValue = annotation.getField('description');
    if (descValue != null && descValue.toStringValue() != null) {
      final desc = descValue.toStringValue()!;
      if (desc.isNotEmpty) {
        data['description'] = desc;
      }
    }

    // Extract type
    final typeValue = annotation.getField('type');
    if (typeValue != null && typeValue.toStringValue() != null) {
      final type = typeValue.toStringValue()!;
      if (type.isNotEmpty) {
        data['type'] = type;
      }
    }

    // Extract example
    final exampleValue = annotation.getField('example');
    if (exampleValue != null && !exampleValue.isNull) {
      // Handle different example types
      if (exampleValue.toStringValue() != null) {
        data['example'] = exampleValue.toStringValue()!;
      } else if (exampleValue.toIntValue() != null) {
        data['example'] = exampleValue.toIntValue()!;
      } else if (exampleValue.toBoolValue() != null) {
        data['example'] = exampleValue.toBoolValue()!;
      } else if (exampleValue.toDoubleValue() != null) {
        data['example'] = exampleValue.toDoubleValue()!;
      }
    }

    // Extract required (note: this overrides the Dart optional/required detection)
    final requiredValue = annotation.getField('required');
    if (requiredValue != null && requiredValue.toBoolValue() != null) {
      data['required'] = requiredValue.toBoolValue()!;
    }

    return data.isEmpty ? null : data;
  }

  /// Generate JSON schema for method parameters
  String? _generateInputSchema(MethodElement method) {
    // First check if the annotation already has an inputSchema
    if (_mcpToolChecker.hasAnnotationOfExact(method)) {
      final annotation = _mcpToolChecker.firstAnnotationOfExact(method);
      if (annotation != null) {
        final inputSchemaValue = annotation.getField('inputSchema');
        if (inputSchemaValue != null && !inputSchemaValue.isNull) {
          // If annotation has inputSchema, we should use it, but for now we'll generate from parameters
          // TODO: Parse the existing inputSchema from the annotation
        }
      }
    }

    final parameters = method.formalParameters;
    if (parameters.isEmpty) {
      return null;
    }

    final properties = <String, Map<String, dynamic>>{};
    final required = <String>[];

    for (final param in parameters) {
      final paramName = param.name;
      if (paramName == null) continue;

      final paramType = _getTypeString(param.type);
      final jsonType = _dartTypeToJsonType(paramType);

      // Start with basic property structure
      final property = <String, dynamic>{
        'type': jsonType,
        'description': '${_capitalizeFirst(paramName)} parameter',
      };

      // Extract MCPParam annotation data if available
      final mcpParamData = _extractMCPParamData(param);
      if (mcpParamData != null) {
        // Override with MCPParam data
        if (mcpParamData.containsKey('description')) {
          property['description'] = mcpParamData['description'];
        }
        if (mcpParamData.containsKey('type')) {
          property['type'] = mcpParamData['type'];
        }
        if (mcpParamData.containsKey('example')) {
          property['example'] = mcpParamData['example'];
        }

        // Handle required override from MCPParam
        if (mcpParamData.containsKey('required')) {
          final isRequired = mcpParamData['required'] as bool;
          if (isRequired && !required.contains(paramName)) {
            required.add(paramName);
          } else if (!isRequired && required.contains(paramName)) {
            required.remove(paramName);
          }
        } else {
          // Use Dart's optional/required detection
          if (!param.isOptional) {
            required.add(paramName);
          }
        }
      } else {
        // No MCPParam annotation, use Dart's optional/required detection
        if (!param.isOptional) {
          required.add(paramName);
        }
      }

      properties[paramName] = property;
    }

    final schema = {
      'type': 'object',
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
    };

    return _mapToString(schema);
  }

  /// Convert Dart type to JSON Schema type
  String _dartTypeToJsonType(String dartType) {
    return switch (dartType.toLowerCase()) {
      'string' => 'string',
      'int' || 'integer' => 'integer',
      'double' || 'num' || 'number' => 'number',
      'bool' || 'boolean' => 'boolean',
      'list<dynamic>' => 'array',
      'map<string, dynamic>' => 'object',
      _ => 'string', // Default fallback
    };
  }

  /// Convert a Map to a string representation for code generation
  String _mapToString(Map<String, dynamic> map) {
    final buffer = StringBuffer('{');
    final entries = map.entries.toList();

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isLast = i == entries.length - 1;

      buffer.write('\n        \'${entry.key}\': ');
      buffer.write(_valueToString(entry.value, 2));
      if (!isLast) buffer.write(',');
    }

    buffer.write('\n      }');
    return buffer.toString();
  }

  /// Convert a value to string representation for code generation
  String _valueToString(dynamic value, int indentLevel) {
    final indent = '  ' * indentLevel;

    if (value is String) {
      return '\'$value\'';
    } else if (value is Map<String, dynamic>) {
      final buffer = StringBuffer('{');
      final entries = value.entries.toList();

      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final isLast = i == entries.length - 1;

        buffer.write('\n$indent  \'${entry.key}\': ');
        buffer.write(_valueToString(entry.value, indentLevel + 1));
        if (!isLast) buffer.write(',');
      }

      buffer.write('\n$indent}');
      return buffer.toString();
    } else if (value is List) {
      final buffer = StringBuffer('[');
      for (int i = 0; i < value.length; i++) {
        final isLast = i == value.length - 1;
        buffer.write(_valueToString(value[i], indentLevel));
        if (!isLast) buffer.write(', ');
      }
      buffer.write(']');
      return buffer.toString();
    } else {
      return value.toString();
    }
  }

  /// Capitalize first letter of a string
  String _capitalizeFirst(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}
