## 1.2.0

- 🎯 **@MCPParam Implementation**: The `@MCPParam` annotation is now fully functional! Add rich metadata to your parameters with custom descriptions, examples, type overrides, and required/optional control.
- 📝 **Enhanced Parameter Documentation**: Generate professional API documentation with meaningful parameter descriptions instead of generic "Parameter parameter" text.
- 🔍 **Parameter Examples**: Include examples in your JSON schemas to help API consumers understand expected values.
- ⚙️ **Fine-grained Control**: Override Dart's type inference and required/optional detection with explicit `@MCPParam` settings.
- 🔄 **Backward Compatible**: Existing code without `@MCPParam` annotations continues to work exactly as before.

### What's New
- **@MCPParam Annotation Processing**: The code generator now reads and processes `@MCPParam` annotations on method parameters
- **Rich JSON Schemas**: Generated input schemas include custom descriptions, examples, and type information from `@MCPParam`
- **Parameter Metadata**: Support for `description`, `example`, `type`, and `required` fields in parameter annotations
- **Type Override Support**: Explicitly specify JSON Schema types that differ from Dart types
- **Required/Optional Control**: Override Dart's optional parameter detection with explicit `required: true/false`

### Example Usage
```dart
@MCPTool('weather', description: 'Get weather information')
Future<Map<String, dynamic>> getWeather(
  @MCPParam(description: 'City name or coordinates', example: 'San Francisco')
  String location,
  
  @MCPParam(
    required: false,
    description: 'Temperature unit',
    example: 'celsius',
    type: 'string'
  )
  String unit = 'celsius',
) async {
  // Your implementation
}
```

### Generated Schema Enhancement
**Before:**
```json
"location": {"type": "string", "description": "Location parameter"}
```

**After:**
```json
"location": {
  "type": "string",
  "description": "City name or coordinates", 
  "example": "San Francisco"
}
```

## 1.1.2

- ✨ **No More @override**: Revolutionary extension-based code generation eliminates the need for `@override` annotations
- 🔧 **Resource Generation Fix**: Fixed critical issue where generator incorrectly passed `uri` parameter to resource methods that don't expect it
- 🧪 **Enhanced Testing**: Added comprehensive resource test example demonstrating both URI-based and simple data provider resources
- 📚 **Better Resource Patterns**: Generator now intelligently detects if resource methods expect URI parameters and handles both patterns correctly
- 🏗️ **Cleaner Architecture**: Extension-based registration provides cleaner inheritance and method declarations

### What's New
- **Extension-Based Registration**: Generated code now creates extensions on your class instead of abstract base classes
- **No @override Required**: Your methods can be declared without `@override` annotations for cleaner code
- **Automatic Registration**: Call `registerGeneratedHandlers()` in your constructor for seamless setup
- **Cleaner Inheritance**: Simply extend `MCPServer` directly without abstract method constraints

### What's Fixed
- Resource methods without URI parameters now work correctly (e.g., `getServerStats()` instead of `getServerStats(uri)`)
- Generator automatically wraps simple return values in `MCPResourceContent` for URI-less resources
- Both traditional URI-based resources and simple data providers are now fully supported
- Eliminated inheritance complexity with extension-based approach

### Example Usage
```dart
// Clean method declarations - no @override needed!
class MyMCPServer extends MCPServer {
  MyMCPServer() : super(name: 'my-server', version: '1.0.0') {
    registerGeneratedHandlers(); // Extension method from generated code
  }

  @MCPTool('greet', description: 'Greet someone')
  Future<String> greet(String name) async {  // No @override!
    return 'Hello, $name!';
  }

  // Traditional resource with URI parameter
  @MCPResource('userProfile')
  Future<MCPResourceContent> getUserProfile(String uri) async { ... }

  // Simple resource without URI parameter (now works!)
  @MCPResource('serverStats') 
  Future<Map<String, dynamic>> getServerStats() async { ... }
}
```

## 1.1.1

- 🔧 **Critical Fix**: Resolved build_runner collision between `source_gen:combining_builder` and `mcp_generator`
- 📝 **File Extension Change**: Generated files now use `.mcp.dart` extension to avoid conflicts with other builders
- 📚 **Documentation Update**: Updated README and examples to reflect new file extension pattern

### Breaking Changes
- Generated files now use `.mcp.dart` extension instead of `.g.dart`
- Update your `part` directives from `part 'filename.g.dart';` to `part 'filename.mcp.dart';`

## 1.1.0

- 🚀 **Auto-registration**: Automatic handler registration using reflection - no need to manually call `registerGeneratedHandlers()`
- 🔧 **Enhanced code generation**: Improved MCP generator with better parameter extraction and JSON schema generation
- 📋 **Smarter annotations**: Code generator now uses annotation names instead of method names for tool/resource/prompt registration
- 🏥 **Health check**: Added `ping` method support for health monitoring
- 🔄 **Protocol upgrade**: Updated to MCP protocol version 2025-06-18
- 🎯 **Better validation**: Improved input schema generation from method parameters with proper type mapping
- 📚 **Enhanced documentation**: Generated code includes better descriptions from annotations
- 🛠️ **New examples**: Added advanced calculator example with comprehensive tool demonstrations
- 🔗 **Improved usability**: Added `stdio()` method as alias for `start()` for better clarity
- ⚙️ **Configuration updates**: Updated MCP config with localhost to 127.0.0.1 for better compatibility
- 🧹 **Code cleanup**: Removed excessive comments from generated code for cleaner output

### Breaking Changes
- Protocol version updated from `2024-11-05` to `2025-06-18`
- Generated handlers now use annotation names instead of method names by default
- Origin validation now defaults to `false` instead of `true` for easier development

## 1.0.1

- 🔧 **Fixed origin validation**: Resolved production deployment issues with CORS origin checking
- 🏗️ **Modular architecture**: Split monolithic server file into focused modules for better maintainability
- ⚙️ **Configurable origin validation**: Added `allowLocalhost` and `validateOrigins` parameters for flexible security
- 🧹 **Code organization**: Separated concerns into `middleware.dart`, `http_handlers.dart`, `session_manager.dart`, and `server_utils.dart`
- 📦 **Package name**: Changed from `dart_mcp` to `mcp_server_dart` for better pub.dev availability
- 🔒 **Enhanced security**: Better HTTPS origin support and customizable allowed origins

### Breaking Changes
- Package name changed from `dart_mcp` to `mcp_server_dart`
- Origin validation now allows HTTPS origins by default (can be disabled with `validateOrigins: false`)

## 1.0.0

- 🚀 **Initial release** of MCP Dart Framework
- 🏷️ **Annotation-based development**: `@MCPTool`, `@MCPResource`, `@MCPPrompt` annotations
- 🔧 **Code generation**: Automatic boilerplate generation using `build_runner`
- 📡 **Multiple transports**: Support for stdio, HTTP, and WebSocket connections
- 🔍 **Type-safe**: Full Dart type safety with automatic parameter extraction
- 📚 **JSON Schema**: Automatic input schema generation from method signatures
- 🌟 **Complete example**: Google Maps MCP server demonstrating all features
- 🧪 **Testing support**: Built-in support for testing MCP servers
- 📖 **Comprehensive docs**: Detailed README with examples and API reference

### Features

- **MCPServer base class** with full MCP protocol implementation
- **Automatic parameter extraction** from method signatures
- **JSON Schema generation** for tool input validation
- **WebSocket and stdio transport** support
- **Resource and prompt management** alongside tools
- **Error handling and logging** built-in
- **Type-safe context access** for tool parameters

### Examples

- Simple MCP server example
- Google Maps MCP server with multiple tools, resources, and prompts
- Comprehensive test suite demonstrating framework usage
