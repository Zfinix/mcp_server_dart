/// Resource Test MCP Server
///
/// Demonstrates:
/// - Resources that take URI parameters (traditional MCP pattern)
/// - Resources that don't take URI parameters (simpler data providers)
/// - Mixed resource types in the same server
library;

import 'dart:math' as math;
import 'package:logging/logging.dart';
import 'package:mcp_server_dart/mcp_server_dart.dart';

part 'resource_test.mcp.dart';

class ResourceTestMCP extends MCPServer {
  ResourceTestMCP()
    : super(
        name: 'resource-test-mcp',
        version: '1.0.0',
        description: 'Test server for different resource patterns',
      ) {
    // Register all generated handlers using the extension
    registerGeneratedHandlers();
  }

  // Traditional MCP resource that expects URI parameter
  @resource(
    'userProfile',
    description: 'Get user profile data by URI',
    mimeType: 'application/json',
  )
  Future<MCPResourceContent> getUserProfile(String uri) async {
    // Extract user ID from URI like "user://123"
    final userId = uri.replaceFirst('user://', '');

    return MCPResourceContent(
      uri: uri,
      name: 'userProfile',
      title: 'User Profile #$userId',
      description: 'Profile information for user $userId',
      mimeType: 'application/json',
      text: jsonEncode({
        'userId': userId,
        'name': 'User $userId',
        'email': 'user$userId@example.com',
        'createdAt': DateTime.now().toIso8601String(),
        'isActive': true,
      }),
    );
  }

  // Simple resource that doesn't need URI parameter
  @resource(
    'serverStats',
    description: 'Current server statistics and metrics',
    mimeType: 'application/json',
  )
  Future<Map<String, dynamic>> getServerStats() async {
    return {
      'server': name,
      'version': version,
      'uptime': DateTime.now().toIso8601String(),
      'memoryUsage': '${math.Random().nextInt(100)}MB',
      'activeConnections': math.Random().nextInt(50),
      'requestsProcessed': math.Random().nextInt(10000),
      'status': 'healthy',
    };
  }

  // Another simple resource without URI
  @resource(
    'systemInfo',
    description: 'System information and environment details',
    mimeType: 'application/json',
  )
  Map<String, dynamic> getSystemInfo() {
    return {
      'platform': 'dart',
      'framework': 'mcp_server_dart',
      'capabilities': ['tools', 'resources', 'prompts'],
      'features': {
        'autoRegistration': true,
        'typeGeneration': true,
        'httpServer': true,
        'stdioTransport': true,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // File-based resource that uses URI to determine content
  @resource(
    'configFile',
    description: 'Configuration file content by path',
    mimeType: 'text/plain',
  )
  Future<MCPResourceContent> getConfigFile(String uri) async {
    // Extract file path from URI like "file:///config/app.json"
    final filePath = uri.replaceFirst('file://', '');

    // Mock file content based on path
    String content;
    String mimeType = 'text/plain';

    if (filePath.endsWith('.json')) {
      content = jsonEncode({
        'configFile': filePath,
        'environment': 'development',
        'debug': true,
        'features': ['logging', 'monitoring', 'caching'],
      });
      mimeType = 'application/json';
    } else if (filePath.endsWith('.yaml') || filePath.endsWith('.yml')) {
      content =
          '''
name: $name
version: $version
environment: development
features:
  - logging
  - monitoring
  - caching
''';
      mimeType = 'text/yaml';
    } else {
      content =
          '''
# Configuration for $name
# Generated at ${DateTime.now().toIso8601String()}

server.name=$name
server.version=$version
server.debug=true
''';
      mimeType = 'text/plain';
    }

    return MCPResourceContent(
      uri: uri,
      name: 'configFile',
      title: 'Config: $filePath',
      description: 'Configuration file at $filePath',
      mimeType: mimeType,
      text: content,
    );
  }

  // Simple tool for testing
  @tool('ping', description: 'Simple ping test')
  Future<Map<String, dynamic>> ping() async {
    return {
      'message': 'pong',
      'timestamp': DateTime.now().toIso8601String(),
      'server': name,
    };
  }
}

void main(List<String> args) async {
  // Enable verbose logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      print('Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('Stack trace: ${record.stackTrace}');
    }
  });

  final server = ResourceTestMCP();

  print('🧪 Resource Test MCP Server');
  print('');
  print('Available resources:');
  print('  - userProfile (expects URI: user://123)');
  print('  - serverStats (no URI needed)');
  print('  - systemInfo (no URI needed)');
  print('  - configFile (expects URI: file:///path/to/config.json)');
  print('');
  print('This server demonstrates different resource patterns:');
  print('  ✓ Traditional resources with URI parameters');
  print('  ✓ Simple data provider resources without URI');
  print('  ✓ Mixed async/sync resource methods');
  print('');

  // Check command line arguments
  if (args.contains('--http')) {
    final port = args.contains('--port')
        ? int.parse(args[args.indexOf('--port') + 1])
        : 8080;

    print('🌐 Starting HTTP server on port $port...');
    print('📊 Test endpoints:');
    print('  Health: http://localhost:$port/health');
    print('  Status: http://localhost:$port/status');
    print('  MCP: http://localhost:$port/mcp');

    await server.serve(port: port);
  } else {
    print('🔌 Starting MCP server on stdio...');
    await server.start();
  }
}
