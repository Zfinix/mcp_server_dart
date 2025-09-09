#!/bin/bash

# MCP Dart Framework - Binary Build Script
# This script builds production-ready MCP server binaries from the examples

set -e

echo "🏗️  Building MCP Dart Framework Examples"
echo "========================================"

# Install dependencies
echo "📦 Installing dependencies..."
dart pub get

# Generate code for advanced examples
echo "🔧 Generating MCP handler code..."
dart run build_runner build --delete-conflicting-outputs

# Create bin directory
echo "📁 Creating bin directory..."
mkdir -p bin

# Compile binaries
echo "🚀 Compiling to native binaries..."

# Hello World example
echo "  👋 Compiling Hello World server..."
dart compile exe lib/basic/hello_world.dart -o bin/hello-world-server

# Calculator example
echo "  🧮 Compiling Calculator server..."
dart compile exe lib/basic/calculator.dart -o bin/calculator-server

# Weather Service example
echo "  🌤️  Compiling Weather Service server..."
dart compile exe lib/advanced/weather_service.dart -o bin/weather-service-server

# Google Maps example
echo "  🗺️  Compiling Google Maps server..."
dart compile exe lib/advanced/google_maps.dart -o bin/google-maps-server

# Main runner
echo "  🚀 Compiling main example runner..."
dart compile exe main.dart -o bin/mcp-examples-runner

# Show results
echo ""
echo "✅ Build completed! Binaries created:"
ls -la bin/
echo ""
echo "🎯 Usage examples:"
echo "  # Individual servers:"
echo "  ./bin/hello-world-server"
echo "  ./bin/calculator-server --http"
echo "  ./bin/weather-service-server --port 3000"
echo "  ./bin/google-maps-server"
echo ""
echo "  # Example runner (choose which server to run):"
echo "  ./bin/mcp-examples-runner --example hello-world"
echo "  ./bin/mcp-examples-runner --example calculator --http"
echo "  ./bin/mcp-examples-runner --example weather --port 3000"
echo "  ./bin/mcp-examples-runner --example google-maps"
echo ""
echo "📋 Claude Desktop configuration:"
echo '{
  "mcpServers": {
    "hello-world": {
      "command": "'$(pwd)'/bin/hello-world-server"
    },
    "calculator": {
      "command": "'$(pwd)'/bin/calculator-server"
    },
    "weather-service": {
      "command": "'$(pwd)'/bin/weather-service-server"
    },
    "google-maps": {
      "command": "'$(pwd)'/bin/google-maps-server"
    }
  }
}'
echo ""
echo "🔍 Testing your servers:"
echo "  # Test individual server health (if using --http mode):"
echo "  curl http://localhost:8080/health"
echo "  curl http://localhost:8080/status"
echo ""
echo "  # Run with help to see all options:"
echo "  ./bin/mcp-examples-runner --help"
echo ""
echo "🚀 All MCP servers are ready for production deployment!"
