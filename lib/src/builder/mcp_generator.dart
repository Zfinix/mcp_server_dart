// ignore_for_file: avoid_types_as_parameter_names

import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:logging/logging.dart';
import 'package:source_gen/source_gen.dart';

import 'template_engine.dart';

// Fully qualified type names for annotation checking
const _toolTypeName = 'package:mcp_server_dart/src/annotations.dart#tool';
const _resourceTypeName =
    'package:mcp_server_dart/src/annotations.dart#resource';
const _promptTypeName = 'package:mcp_server_dart/src/annotations.dart#prompt';
const _completionTypeName =
    'package:mcp_server_dart/src/annotations.dart#completion';
const _paramTypeName = 'package:mcp_server_dart/src/annotations.dart#param';

/// Builder function for build.yaml
Builder mcpBuilder(BuilderOptions options) =>
    LibraryBuilder(MCPGenerator(), generatedExtension: '.mcp.dart');

/// Generator that processes annotated methods in MCP classes and
/// annotated top-level functions to produce registration code.
class MCPGenerator extends Generator {
  static final _logger = Logger('MCPGenerator');

  // Type checkers for MCP annotations (both lowercase and alias forms)
  static const _mcpToolChecker = TypeChecker.any([
    TypeChecker.fromUrl(_toolTypeName),
    TypeChecker.fromUrl('package:mcp_server_dart/src/annotations.dart#MCPTool'),
  ]);
  static const _mcpResourceChecker = TypeChecker.any([
    TypeChecker.fromUrl(_resourceTypeName),
    TypeChecker.fromUrl(
      'package:mcp_server_dart/src/annotations.dart#MCPResource',
    ),
  ]);
  static const _mcpPromptChecker = TypeChecker.any([
    TypeChecker.fromUrl(_promptTypeName),
    TypeChecker.fromUrl(
      'package:mcp_server_dart/src/annotations.dart#MCPPrompt',
    ),
  ]);
  static const _mcpCompletionChecker = TypeChecker.any([
    TypeChecker.fromUrl(_completionTypeName),
    TypeChecker.fromUrl(
      'package:mcp_server_dart/src/annotations.dart#MCPCompletion',
    ),
  ]);
  static const _mcpParamChecker = TypeChecker.any([
    TypeChecker.fromUrl(_paramTypeName),
    TypeChecker.fromUrl(
      'package:mcp_server_dart/src/annotations.dart#MCPParam',
    ),
  ]);

  @override
  FutureOr<String?> generate(LibraryReader library, BuildStep buildStep) {
    final sourceFile = buildStep.inputId.path.split('/').last;
    final buffer = StringBuffer();

    bool hasAnyMCPAnnotations = false;

    // Find the most concrete MCPServer subclass (if any) in this library
    ClassElement? mcpServerClass;
    int mcpServerDepth = -1;
    List<MethodElement> mcpServerMethods = [];

    // Collect annotated top-level functions defined in THIS library
    final localTopLevelFunctions = <TopLevelFunctionElement>[];

    // Process all elements in the library
    for (final element in library.allElements) {
      if (element is ClassElement) {
        final className = element.name;
        if (className == null) continue;

        final isMCPServer = _isMCPServerSubclass(element);

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

        if (isMCPServer) {
          final depth = _inheritanceDepth(element);
          if (depth > mcpServerDepth) {
            mcpServerClass = element;
            mcpServerDepth = depth;
            mcpServerMethods = annotatedMethods;
          }
        } else if (annotatedMethods.isNotEmpty) {
          // Non-MCPServer class with annotated methods — generate its own
          // extension as before.
          hasAnyMCPAnnotations = true;
          buffer.writeln(
            _generateExtension(className, annotatedMethods, sourceFile),
          );
        }
      } else if (element is TopLevelFunctionElement) {
        if (element.name != null &&
            !element.isPrivate &&
            !element.name!.startsWith('_') &&
            _hasAnyMCPAnnotation(element)) {
          localTopLevelFunctions.add(element);
        }
      }
    }

    if (mcpServerClass != null) {
      // MCPServer subclass found — scan imported libraries for annotated
      // top-level functions and merge everything into one extension.
      final importedFunctions = _collectImportedAnnotatedFunctions(
        library.element,
      );
      final allTopLevelFunctions = [
        ...localTopLevelFunctions,
        ...importedFunctions,
      ];

      if (mcpServerMethods.isNotEmpty || allTopLevelFunctions.isNotEmpty) {
        hasAnyMCPAnnotations = true;
        buffer.writeln(
          _generateExtension(
            mcpServerClass.name!,
            mcpServerMethods,
            sourceFile,
            topLevelFunctions: allTopLevelFunctions,
          ),
        );
      }
    } else if (localTopLevelFunctions.isNotEmpty) {
      // Standalone file with annotated functions but NO MCPServer class.
      // Don't generate anything — the server's generator will pick these
      // up when it scans its imports.
      return null;
    }

    // Only return generated code if we actually found MCP annotations
    if (!hasAnyMCPAnnotations) return null;

    // Prepend part-of header (LibraryBuilder does not add this automatically)
    final output = StringBuffer();
    output.writeln('// ignore_for_file: type=lint');
    output.writeln("part of '$sourceFile';");
    output.writeln();
    output.write(buffer.toString());

    // Format the generated code with dart_style
    final formatter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    );
    try {
      return formatter.format(output.toString());
    } catch (e) {
      // If formatting fails, return unformatted code
      _logger.warning('Failed to format generated code: $e');
      return output.toString();
    }
  }

  String _generateExtension(
    String className,
    List<MethodElement> methods,
    String sourceFile, {
    List<TopLevelFunctionElement>? topLevelFunctions,
  }) {
    // Generate handler registrations for class methods (no prefix, no
    // mcpServerExpression — the method is called on `this` implicitly)
    final registrationParts = <String>[];
    for (final method in methods) {
      registrationParts.add(_generateHandlerRegistration(method));
    }

    // Generate handler registrations for top-level functions (local or
    // imported).  Inside the extension, `this` IS the MCPServer so we
    // pass mcpServerExpression: 'this'.
    if (topLevelFunctions != null) {
      for (final fn in topLevelFunctions) {
        registrationParts.add(
          _generateHandlerRegistration(fn, mcpServerExpression: 'this'),
        );
      }
    }

    final handlerRegistrations = registrationParts.join('\n\n');

    // Generate usage capabilities
    final allElements = <ExecutableElement>[
      ...methods,
      if (topLevelFunctions != null) ...topLevelFunctions,
    ];

    final availableTools = allElements
        .where((m) => _getAnnotationType(m) == 'MCPTool')
        .map((m) => _getAnnotationName(m))
        .toList();
    final availableResources = allElements
        .where((m) => _getAnnotationType(m) == 'MCPResource')
        .map((m) => _getAnnotationName(m))
        .toList();
    final availablePrompts = allElements
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

  /// Generate handler registration for a single executable element
  /// (either a class method or a top-level function).
  ///
  /// When [serverPrefix] is non-empty (e.g. 'server.'), the generated
  /// `registerTool` / `registerResource` / `registerPrompt` calls are
  /// prefixed with it, e.g. `server.registerTool(...)`.
  ///
  /// When [mcpServerExpression] is provided (e.g. 'this'), it is used as the
  /// value for MCPServer-typed parameters instead of the default
  /// `server as ConcreteType`.  This is used when top-level functions are
  /// merged into a class extension.
  String _generateHandlerRegistration(
    ExecutableElement method, {
    String serverPrefix = '',
    String? mcpServerExpression,
  }) {
    final annotationType = _getAnnotationType(method);
    final annotationName = _getAnnotationName(method);
    final annotationDescription = _getAnnotationDescription(method);
    final annotationTitle = _getAnnotationTitle(method);
    final annotationIcons = _getAnnotationIconsLiteral(method);
    final toolAnnotations = _getToolAnnotationsLiteral(method);
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
      // (excluding MCPToolContext and MCPServer params — these are injected)
      final extractions = method.formalParameters
          .where(
            (param) => !_isMCPToolContext(param) && !_isMCPServerParam(param),
          )
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
      // Positional args (excluding MCPToolContext and MCPServer)

      // Named args (excluding MCPToolContext and MCPServer — we'll add those separately)
      final namedArgs = method.formalParameters
          .where(
            (p) =>
                p.isNamed &&
                p.name != null &&
                !_isMCPToolContext(p) &&
                !_isMCPServerParam(p),
          )
          .map((p) => '${p.name}: ${p.name}')
          .toList();

      // Check if method accepts MCPToolContext and add it if so
      final hasContextParam = method.formalParameters.any(
        (p) => _isMCPToolContext(p),
      );
      if (hasContextParam) {
        namedArgs.add('context: context');
      }

      // Check if method accepts an MCPServer parameter and pass `server`
      final serverParam = method.formalParameters.cast<dynamic>().firstWhere(
        (p) => _isMCPServerParam(p),
        orElse: () => null,
      );
      if (serverParam != null) {
        final serverParamName = serverParam.name as String;
        String castExpr;
        if (mcpServerExpression != null) {
          castExpr = mcpServerExpression;
        } else {
          final serverParamType = _getTypeString(serverParam.type as DartType);
          castExpr = serverParamType == 'MCPServer'
              ? 'server'
              : 'server as $serverParamType';
        }
        if (serverParam.isNamed) {
          namedArgs.add('$serverParamName: $castExpr');
        }
      }

      // Build positional args list (server param may be positional)
      final positionalParts = <String>[];
      for (final p in method.formalParameters) {
        if (!p.isRequiredPositional || p.name == null) continue;
        if (_isMCPToolContext(p)) continue;
        if (_isMCPServerParam(p)) {
          if (mcpServerExpression != null) {
            positionalParts.add(mcpServerExpression);
          } else {
            final pType = _getTypeString(p.type);
            positionalParts.add(
              pType == 'MCPServer' ? 'server' : 'server as $pType',
            );
          }
        } else {
          positionalParts.add(p.name!);
        }
      }

      final args = [
        if (positionalParts.isNotEmpty) positionalParts.join(', '),
        if (namedArgs.isNotEmpty) namedArgs.join(', '),
      ].where((s) => s.isNotEmpty).join(', ');

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
      } else {
        inputSchemaStr = '      inputSchema: {},';
      }
      final titleStr = annotationTitle != null
          ? "      title: '${_escapeDartString(annotationTitle)}',"
          : '';
      final annotationsStr = toolAnnotations != null
          ? '      annotations: $toolAnnotations,'
          : '';
      final iconsStr = annotationIcons != null
          ? '      icons: $annotationIcons,'
          : '';

      return TemplateEngine.renderTemplateFromString(
        TemplateEngine.toolHandlerTemplate,
        {
          'serverPrefix': serverPrefix,
          'annotationName': annotationName,
          'methodDoc': methodDocComment,
          'parameterExtractions': parameterExtractions,
          'returnStatement': returnStatement,
          'description': annotationDescription.isNotEmpty
              ? annotationDescription
              : 'Generated handler for $methodName',
          'title': titleStr,
          'annotations': annotationsStr,
          'icons': iconsStr,
          'inputSchema': inputSchemaStr,
        },
      );
    } else if (annotationType == 'MCPResource') {
      final args = <String>[];
      for (final p in method.formalParameters) {
        if (p.name == null) continue;
        if (_isMCPServerParam(p)) {
          if (mcpServerExpression != null) {
            args.add(mcpServerExpression);
          } else {
            final pType = _getTypeString(p.type);
            args.add(pType == 'MCPServer' ? 'server' : 'server as $pType');
          }
        } else if (p.name == 'uri') {
          args.add('uri');
        }
      }

      final callArgs = args.join(', ');
      final callExpr = method.returnType.toString().contains('Future')
          ? 'await $methodName($callArgs)'
          : '$methodName($callArgs)';

      final returnsResourceContent = method.returnType.toString().contains(
        'MCPResourceContent',
      );

      if (returnsResourceContent) {
        returnStatement = 'return $callExpr';
      } else {
        returnStatement =
            '''final result = $callExpr;
        return MCPResourceContent(
          uri: uri,
          name: '$annotationName',
          mimeType: 'application/json',
          text: jsonEncode(result),
        )''';
      }

      final titleStr = annotationTitle != null
          ? "      title: '${_escapeDartString(annotationTitle)}',"
          : '';
      final iconsStr = annotationIcons != null
          ? '      icons: $annotationIcons,'
          : '';

      return TemplateEngine.renderTemplateFromString(
        TemplateEngine.resourceHandlerTemplate,
        {
          'serverPrefix': serverPrefix,
          'annotationName': annotationName,
          'methodDoc': methodDocComment,
          'title': titleStr,
          'icons': iconsStr,
          'returnStatement': returnStatement,
        },
      );
    } else if (annotationType == 'MCPPrompt') {
      // For prompts, check if method takes Map<String, dynamic> directly
      final nonServerParams = method.formalParameters
          .where((p) => !_isMCPServerParam(p))
          .toList();
      final hasMapParameter =
          nonServerParams.length == 1 &&
          nonServerParams.first.type.toString().contains(
            'Map<String, dynamic>',
          );

      if (hasMapParameter) {
        final callArgs = <String>[];
        for (final p in method.formalParameters) {
          if (_isMCPServerParam(p)) {
            if (mcpServerExpression != null) {
              callArgs.add(mcpServerExpression);
            } else {
              final pType = _getTypeString(p.type);
              callArgs.add(
                pType == 'MCPServer' ? 'server' : 'server as $pType',
              );
            }
          } else {
            callArgs.add('args');
          }
        }
        returnStatement = 'return $methodName(${callArgs.join(', ')})';
      } else {
        // Extract individual parameters from args Map
        final extractions = method.formalParameters
            .where((param) => !_isMCPServerParam(param))
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
        final positionalArgs = <String>[];
        for (final p in method.formalParameters) {
          if (!p.isRequiredPositional || p.name == null) continue;
          if (_isMCPServerParam(p)) {
            if (mcpServerExpression != null) {
              positionalArgs.add(mcpServerExpression);
            } else {
              final pType = _getTypeString(p.type);
              positionalArgs.add(
                pType == 'MCPServer' ? 'server' : 'server as $pType',
              );
            }
          } else {
            positionalArgs.add(p.name!);
          }
        }
        final namedArgs = method.formalParameters
            .where((p) => p.isNamed && p.name != null && !_isMCPServerParam(p))
            .map((p) => '${p.name}: ${p.name}')
            .toList();
        for (final p in method.formalParameters.where(_isMCPServerParam)) {
          final pName = p.name;
          if (pName == null || !p.isNamed) continue;
          if (mcpServerExpression != null) {
            namedArgs.add('$pName: $mcpServerExpression');
          } else {
            final pType = _getTypeString(p.type);
            namedArgs.add(
              '$pName: ${pType == 'MCPServer' ? 'server' : 'server as $pType'}',
            );
          }
        }

        final args = [
          if (positionalArgs.isNotEmpty) positionalArgs.join(', '),
          if (namedArgs.isNotEmpty) namedArgs.join(', '),
        ].join(', ');

        returnStatement = 'return $methodName($args)';
      }

      final titleStr = annotationTitle != null
          ? "      title: '${_escapeDartString(annotationTitle)}',"
          : '';
      final iconsStr = annotationIcons != null
          ? '      icons: $annotationIcons,'
          : '';

      return TemplateEngine.renderTemplateFromString(
        TemplateEngine.promptHandlerTemplate,
        {
          'serverPrefix': serverPrefix,
          'annotationName': annotationName,
          'methodDoc': methodDocComment,
          'title': titleStr,
          'icons': iconsStr,
          'parameterExtractions': parameterExtractions,
          'returnStatement': returnStatement,
        },
      );
    } else if (annotationType == 'MCPCompletion') {
      final registerMethod = annotationName.startsWith('mcp://')
          ? '${serverPrefix}registerResourceCompletion'
          : '${serverPrefix}registerPromptCompletion';

      final args = <String>[];
      for (final p in method.formalParameters) {
        if (_isMCPServerParam(p)) {
          if (mcpServerExpression != null) {
            args.add(mcpServerExpression);
          } else {
            final pType = _getTypeString(p.type);
            args.add(pType == 'MCPServer' ? 'server' : 'server as $pType');
          }
        } else if (_isMCPCompletionRequestParam(p)) {
          args.add('request');
        }
      }

      final callExpr = method.returnType.toString().contains('Future')
          ? 'await $methodName(${args.join(', ')})'
          : '$methodName(${args.join(', ')})';

      return TemplateEngine.renderTemplateFromString(
        TemplateEngine.completionHandlerTemplate,
        {
          'annotationName': annotationName,
          'methodDoc': methodDocComment,
          'registerMethod': registerMethod,
          'returnStatement': 'return $callExpr',
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

  /// Check if a parameter is of type MCPToolContext
  bool _isMCPToolContext(dynamic param) {
    final paramType = param.type;
    // Check if the type is MCPToolContext or MCPToolContext?
    final typeString = paramType.getDisplayString();
    return typeString.contains('MCPToolContext');
  }

  /// Check if a parameter is of type MCPCompletionRequest.
  bool _isMCPCompletionRequestParam(dynamic param) {
    final paramType = param.type;
    final typeString = paramType.getDisplayString();
    return typeString.contains('MCPCompletionRequest');
  }

  /// Check if a parameter is of type MCPServer or a subclass thereof.
  ///
  /// These parameters are automatically injected by the generated registration
  /// function and should not appear in the tool's input schema.
  bool _isMCPServerParam(dynamic param) {
    final paramType = param.type;
    if (paramType is! InterfaceType) return false;
    // Walk the supertype chain looking for MCPServer
    InterfaceType? current = paramType;
    while (current != null) {
      final name = current.element.name;
      if (name == 'MCPServer') return true;
      current = current.superclass;
    }
    return false;
  }

  /// Check if an element has any MCP annotation.
  ///
  /// Works with both [MethodElement] (class methods) and
  /// [FunctionElement] (top-level functions).
  bool _hasAnyMCPAnnotation(Element element) {
    // Use the type checkers to properly detect MCP annotations
    return _mcpToolChecker.hasAnnotationOfExact(element) ||
        _mcpResourceChecker.hasAnnotationOfExact(element) ||
        _mcpPromptChecker.hasAnnotationOfExact(element) ||
        _mcpCompletionChecker.hasAnnotationOfExact(element);
  }

  /// Get the annotation type for an element.
  String _getAnnotationType(Element element) {
    if (_mcpToolChecker.hasAnnotationOfExact(element)) {
      return 'MCPTool';
    } else if (_mcpResourceChecker.hasAnnotationOfExact(element)) {
      return 'MCPResource';
    } else if (_mcpPromptChecker.hasAnnotationOfExact(element)) {
      return 'MCPPrompt';
    } else if (_mcpCompletionChecker.hasAnnotationOfExact(element)) {
      return 'MCPCompletion';
    }
    return 'MCPTool'; // Default fallback
  }

  /// Extract the name from the annotation on an element.
  String _getAnnotationName(Element element) {
    // Try to get the name from the annotation, fallback to element name
    if (_mcpToolChecker.hasAnnotationOfExact(element)) {
      final annotation = _mcpToolChecker.firstAnnotationOfExact(element);
      if (annotation != null) {
        final nameValue = annotation.getField('name');
        if (nameValue != null && nameValue.toStringValue() != null) {
          return nameValue.toStringValue()!;
        }
      }
    } else if (_mcpResourceChecker.hasAnnotationOfExact(element)) {
      final annotation = _mcpResourceChecker.firstAnnotationOfExact(element);
      if (annotation != null) {
        final nameValue = annotation.getField('name');
        if (nameValue != null && nameValue.toStringValue() != null) {
          return nameValue.toStringValue()!;
        }
      }
    } else if (_mcpPromptChecker.hasAnnotationOfExact(element)) {
      final annotation = _mcpPromptChecker.firstAnnotationOfExact(element);
      if (annotation != null) {
        final nameValue = annotation.getField('name');
        if (nameValue != null && nameValue.toStringValue() != null) {
          return nameValue.toStringValue()!;
        }
      }
    } else if (_mcpCompletionChecker.hasAnnotationOfExact(element)) {
      final annotation = _mcpCompletionChecker.firstAnnotationOfExact(element);
      if (annotation != null) {
        final targetValue = annotation.getField('target');
        if (targetValue != null && targetValue.toStringValue() != null) {
          return targetValue.toStringValue()!;
        }
      }
    }

    return element.name!;
  }

  /// Extract the title from the annotation on an element.
  String? _getAnnotationTitle(Element element) {
    DartObject? annotation;
    if (_mcpToolChecker.hasAnnotationOfExact(element)) {
      annotation = _mcpToolChecker.firstAnnotationOfExact(element);
    } else if (_mcpResourceChecker.hasAnnotationOfExact(element)) {
      annotation = _mcpResourceChecker.firstAnnotationOfExact(element);
    } else if (_mcpPromptChecker.hasAnnotationOfExact(element)) {
      annotation = _mcpPromptChecker.firstAnnotationOfExact(element);
    }

    if (annotation == null) return null;
    final titleValue = annotation.getField('title');
    final title = titleValue?.toStringValue();
    return (title != null && title.isNotEmpty) ? title : null;
  }

  /// Extract the description from the annotation on an element.
  String _getAnnotationDescription(Element element) {
    if (_mcpToolChecker.hasAnnotationOfExact(element)) {
      final annotation = _mcpToolChecker.firstAnnotationOfExact(element);
      if (annotation != null) {
        final descValue = annotation.getField('description');
        if (descValue != null && descValue.toStringValue() != null) {
          return descValue.toStringValue()!;
        }
      }
    } else if (_mcpResourceChecker.hasAnnotationOfExact(element)) {
      final annotation = _mcpResourceChecker.firstAnnotationOfExact(element);
      if (annotation != null) {
        final descValue = annotation.getField('description');
        if (descValue != null && descValue.toStringValue() != null) {
          return descValue.toStringValue()!;
        }
      }
    } else if (_mcpPromptChecker.hasAnnotationOfExact(element)) {
      final annotation = _mcpPromptChecker.firstAnnotationOfExact(element);
      if (annotation != null) {
        final descValue = annotation.getField('description');
        if (descValue != null && descValue.toStringValue() != null) {
          return descValue.toStringValue()!;
        }
      }
    }

    return '';
  }

  String? _getAnnotationIconsLiteral(Element element) {
    DartObject? annotation;
    if (_mcpToolChecker.hasAnnotationOfExact(element)) {
      annotation = _mcpToolChecker.firstAnnotationOfExact(element);
    } else if (_mcpResourceChecker.hasAnnotationOfExact(element)) {
      annotation = _mcpResourceChecker.firstAnnotationOfExact(element);
    } else if (_mcpPromptChecker.hasAnnotationOfExact(element)) {
      annotation = _mcpPromptChecker.firstAnnotationOfExact(element);
    }
    final iconsField = annotation?.getField('icons');
    final iconObjects = iconsField?.toListValue();
    if (iconObjects == null || iconObjects.isEmpty) return null;

    final parts = <String>[];
    for (final icon in iconObjects) {
      final iconMap = icon.toMapValue();
      if (iconMap == null || iconMap.isEmpty) continue;

      String? readStringField(String key) {
        for (final entry in iconMap.entries) {
          final entryKey = entry.key?.toStringValue();
          if (entryKey == key) {
            return entry.value?.toStringValue();
          }
        }
        return null;
      }

      final src = readStringField('src');
      if (src == null || src.isEmpty) continue;
      final mimeType = readStringField('mimeType');
      final sizes = readStringField('sizes');
      parts.add(
        "MCPIcon(src: '${_escapeDartString(src)}'"
        "${mimeType != null ? ", mimeType: '${_escapeDartString(mimeType)}'" : ''}"
        "${sizes != null ? ", sizes: '${_escapeDartString(sizes)}'" : ''})",
      );
    }

    if (parts.isEmpty) return null;
    return '[${parts.join(', ')}]';
  }

  String? _getToolAnnotationsLiteral(Element element) {
    if (!_mcpToolChecker.hasAnnotationOfExact(element)) return null;
    final annotation = _mcpToolChecker.firstAnnotationOfExact(element);
    final annField = annotation?.getField('annotations');
    final annMap = annField?.toMapValue();
    if (annMap == null || annMap.isEmpty) return null;

    final args = <String>[];
    for (final entry in annMap.entries) {
      final key = entry.key?.toStringValue();
      if (key == null) continue;
      switch (key) {
        case 'readOnlyHint':
        case 'destructiveHint':
        case 'idempotentHint':
        case 'openWorldHint':
          final boolValue = entry.value?.toBoolValue();
          if (boolValue != null) {
            args.add('$key: $boolValue');
          }
          break;
        case 'taskSupport':
        case 'title':
          final stringValue = entry.value?.toStringValue();
          if (stringValue != null && stringValue.isNotEmpty) {
            args.add("$key: '${_escapeDartString(stringValue)}'");
          }
          break;
      }
    }

    if (args.isEmpty) return null;
    return 'MCPToolAnnotations(${args.join(', ')})';
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

    // Extract required only if explicitly set (not null)
    // This allows Dart's type inference to take precedence by default
    final requiredValue = annotation.getField('required');
    if (requiredValue != null && !requiredValue.isNull) {
      final boolValue = requiredValue.toBoolValue();
      if (boolValue != null) {
        data['required'] = boolValue;
      }
    }

    return data.isEmpty ? null : data;
  }

  /// Generate JSON schema for method/function parameters
  String? _generateInputSchema(ExecutableElement method) {
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

      // Skip MCPToolContext parameters - they're not part of the input schema
      if (_isMCPToolContext(param)) continue;

      // Skip MCPServer parameters - injected automatically by registration
      if (_isMCPServerParam(param)) continue;

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

        // Handle required override from MCPParam if explicitly set
        if (mcpParamData.containsKey('required')) {
          final isRequired = mcpParamData['required'] as bool;
          if (isRequired && !required.contains(paramName)) {
            required.add(paramName);
          } else if (!isRequired && required.contains(paramName)) {
            required.remove(paramName);
          }
        } else {
          // Use Dart's type system to determine if parameter is required:
          // - Required positional parameters (not in [] or {})
          // - Required named parameters (has 'required' keyword)
          final dartRequiresParam =
              param.isRequiredPositional || param.isRequiredNamed;
          if (dartRequiresParam) {
            required.add(paramName);
          }
        }
      } else {
        // No MCPParam annotation, use Dart's type system
        final dartRequiresParam =
            param.isRequiredPositional || param.isRequiredNamed;
        if (dartRequiresParam) {
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
    final normalized = dartType
        .trim()
        .replaceAll('?', '')
        .replaceAll('Object?', 'Object')
        .toLowerCase();

    if (normalized == 'string') return 'string';
    if (normalized == 'int' || normalized == 'integer') return 'integer';
    if (normalized == 'double' ||
        normalized == 'num' ||
        normalized == 'number') {
      return 'number';
    }
    if (normalized == 'bool' || normalized == 'boolean') return 'boolean';
    if (normalized.startsWith('list<') || normalized == 'list') return 'array';
    if (normalized.startsWith('map<') || normalized == 'map') return 'object';

    return 'string'; // Default fallback
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

  String _escapeDartString(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll(r'$', r'\$')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }

  /// Capitalize first letter of a string
  String _capitalizeFirst(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  /// Check if a [ClassElement] is a subclass of MCPServer.
  ///
  /// Walks the supertype chain to detect MCPServer anywhere in the hierarchy.
  bool _isMCPServerSubclass(ClassElement element) {
    InterfaceType? current = element.supertype;
    while (current != null) {
      if (current.element.name == 'MCPServer') return true;
      current = current.superclass;
    }
    return false;
  }

  /// Measure how deep a class is in its superclass chain.
  ///
  /// Used to prefer the most concrete MCPServer subclass in a library.
  int _inheritanceDepth(ClassElement element) {
    var depth = 0;
    InterfaceType? current = element.supertype;
    while (current != null) {
      depth++;
      current = current.superclass;
    }
    return depth;
  }

  /// Scan all libraries imported by [libraryElement] and collect annotated
  /// top-level functions.
  ///
  /// This enables the "one generated file" pattern: `server.dart` imports
  /// standalone tool files, the generator discovers their annotations, and
  /// bundles all registrations into `server.mcp.dart`.
  List<TopLevelFunctionElement> _collectImportedAnnotatedFunctions(
    LibraryElement libraryElement,
  ) {
    final results = <TopLevelFunctionElement>[];
    final visited = <String>{};

    for (final imported in libraryElement.firstFragment.importedLibraries) {
      final uri = imported.uri.toString();
      // Skip dart: and package: libraries that aren't ours
      if (uri.startsWith('dart:')) continue;
      // Skip the mcp_server_dart package itself
      if (uri.startsWith('package:mcp_server_dart/')) continue;
      // Avoid visiting the same library twice
      if (!visited.add(uri)) continue;

      // Walk all top-level functions in this imported library
      for (final fn in imported.topLevelFunctions) {
        final name = fn.name;
        if (name == null ||
            name.isEmpty ||
            fn.isPrivate ||
            name.startsWith('_')) {
          continue;
        }
        if (_hasAnyMCPAnnotation(fn)) {
          results.add(fn);
        }
      }
    }

    return results;
  }
}
