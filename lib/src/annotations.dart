/// Annotation classes for declarative MCP server development
// ignore_for_file: camel_case_types

library;

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

  /// Optional schema for input parameters (JSON Schema format)
  final Map<String, dynamic>? inputSchema;

  const tool(this.name, {this.description = '', this.inputSchema});
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

  /// The MIME type of the resource content
  final String? mimeType;

  const resource(this.name, {this.description = '', this.mimeType});
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

  /// Optional arguments that this prompt accepts
  final List<String>? arguments;

  const prompt(this.name, {this.description = '', this.arguments});
}

/// Annotation to mark a parameter as required or provide additional metadata
class param {
  /// Whether this parameter is required
  final bool required;

  /// Description of the parameter
  final String description;

  /// The JSON Schema type of this parameter
  final String? type;

  /// Example value for this parameter
  final dynamic example;

  const param({
    this.required = true,
    this.description = '',
    this.type,
    this.example,
  });
}
