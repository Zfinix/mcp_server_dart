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
