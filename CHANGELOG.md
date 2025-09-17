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
