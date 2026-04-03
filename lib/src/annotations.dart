/// Annotation classes for declarative MCP server development
// ignore_for_file: camel_case_types

library;

// Type aliases for cleaner API - use @MCPTool, @MCPResource, @MCPPrompt, @MCPParam
typedef MCPTool = tool;
typedef MCPResource = resource;
typedef MCPPrompt = prompt;
typedef MCPParam = param;

/// Annotation to mark a method as an MCP tool.
///
/// Tools are functions that the LLM can call to perform actions or retrieve information.
///
/// Example:
/// ```dart
/// @MCPTool('search_web', description: 'Search the web for information')
/// Future<Map<String, dynamic>> searchWeb(String query) async {
///   // Implementation
/// }
/// ```
@override
class tool {
  /// The name of the tool as it will appear to the LLM
  final String name;

  /// A description of what this tool does
  final String description;

  /// Optional human-friendly display title.
  final String? title;

  /// Optional schema for input parameters (JSON Schema format)
  final Map<String, dynamic>? inputSchema;

  /// Optional icon sources metadata.
  final List<Map<String, dynamic>>? icons;

  /// Optional tool behavior metadata hints.
  final Map<String, dynamic>? annotations;

  const tool(
    this.name, {
    this.description = '',
    this.title,
    this.inputSchema,
    this.icons,
    this.annotations,
  });
}

/// Annotation to mark a method as an MCP resource.
///
/// Resources are pieces of data that the LLM can read to understand context.
///
/// Example:
/// ```dart
/// @MCPResource('user_profile', description: 'Current user profile information')
/// Future<MCPResourceContent> getUserProfile(String uri) async {
///   final data = {'id': userId, 'name': 'John Doe'};
///   return MCPResourceContent(
///     uri: uri,
///     mimeType: 'application/json',
///     text: jsonEncode(data),
///   );
/// }
/// ```
class resource {
  /// The name of the resource as it will appear to the LLM
  final String name;

  /// A description of what this resource contains
  final String description;

  /// Optional human-friendly display title.
  final String? title;

  /// The MIME type of the resource content
  final String? mimeType;

  /// Optional icon sources metadata.
  final List<Map<String, dynamic>>? icons;

  const resource(
    this.name, {
    this.description = '',
    this.title,
    this.mimeType,
    this.icons,
  });
}

/// Annotation to mark a method as an MCP prompt.
///
/// Prompts are reusable prompt templates that can be used by the LLM.
///
/// Example:
/// ```dart
/// @MCPPrompt('code_review', description: 'Review code for best practices')
/// String codeReviewPrompt(String code, String language) {
///   return 'Please review this $language code: $code';
/// }
/// ```
class prompt {
  /// The name of the prompt as it will appear to the LLM
  final String name;

  /// A description of what this prompt does
  final String description;

  /// Optional human-friendly display title.
  final String? title;

  /// Optional arguments that this prompt accepts
  final List<String>? arguments;

  /// Optional icon sources metadata.
  final List<Map<String, dynamic>>? icons;

  const prompt(
    this.name, {
    this.description = '',
    this.title,
    this.arguments,
    this.icons,
  });
}

/// Annotation to mark a parameter as required or provide additional metadata.
///
/// By default, the generator uses Dart's type system to determine if a parameter
/// is required (positional params and `required` named params are required,
/// optional named params and nullable types are optional). Use this annotation
/// to override that behavior or provide additional metadata.
class param {
  /// Whether this parameter is required. If null, uses Dart's type inference
  /// (positional params and `required` named params are required).
  final bool? required;

  /// Description of the parameter
  final String description;

  /// The JSON Schema type of this parameter
  final String? type;

  /// Example value for this parameter
  final dynamic example;

  const param({
    this.required,
    this.description = '',
    this.type,
    this.example,
  });
}
