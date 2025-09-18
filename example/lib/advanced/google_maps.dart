/// Example Google Maps MCP Server demonstrating the framework
///
/// This example shows how to create an MCP server using annotations.
/// The framework will automatically generate registration code for all
/// annotated methods.
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:mcp_server_dart/mcp_server_dart.dart';

part 'google_maps.mcp.dart';

/// A Google Maps MCP server with various location-based tools
class GoogleMapsMCP extends MCPServer {
  GoogleMapsMCP()
    : super(
        name: 'google-maps-mcp',
        version: '1.0.0',
        description: 'MCP server providing Google Maps functionality',
      ) {
    // Register all generated handlers using the extension
    registerGeneratedHandlers();
  }

  /// Search for places by name or address
  @MCPTool('searchPlace', description: 'Find places by name or address')
  Future<Map<String, dynamic>> searchPlace(
    String query, {
    int limit = 5,
  }) async {
    // Simulate API call delay
    await Future.delayed(Duration(milliseconds: 200));

    // Mock search results
    final results = [
      {
        'name': '$query - Main Location',
        'address': '123 Main St, City, State 12345',
        'lat': 40.7128 + Random().nextDouble() * 0.1,
        'lng': -74.0060 + Random().nextDouble() * 0.1,
        'rating': 4.2 + Random().nextDouble() * 0.8,
        'types': ['establishment', 'point_of_interest'],
      },
      {
        'name': '$query - Secondary Location',
        'address': '456 Oak Ave, City, State 12346',
        'lat': 40.7128 + Random().nextDouble() * 0.1,
        'lng': -74.0060 + Random().nextDouble() * 0.1,
        'rating': 3.8 + Random().nextDouble() * 1.2,
        'types': ['establishment'],
      },
    ];

    return {
      'query': query,
      'results': results.take(limit).toList(),
      'total_found': results.length,
    };
  }

  /// Get directions between two locations
  @MCPTool('getDirections', description: 'Get directions between two points')
  Future<Map<String, dynamic>> getDirections(
    String origin,
    String destination, {
    String mode = 'driving',
  }) async {
    // Simulate API call
    await Future.delayed(Duration(milliseconds: 300));

    final distance = 5.2 + Random().nextDouble() * 20;
    final duration = mode == 'walking'
        ? (distance * 12)
              .round() // ~12 min per km walking
        : (distance * 2).round(); // ~2 min per km driving

    return {
      'origin': origin,
      'destination': destination,
      'mode': mode,
      'distance': {
        'text': '${distance.toStringAsFixed(1)} km',
        'value': (distance * 1000).round(),
      },
      'duration': {'text': '$duration min', 'value': duration * 60},
      'steps': [
        {
          'instruction': 'Head north on Main St',
          'distance': '0.5 km',
          'duration': '2 min',
        },
        {
          'instruction': 'Turn right onto Oak Ave',
          'distance': '1.2 km',
          'duration': '3 min',
        },
        {
          'instruction':
              'Continue straight for ${(distance - 1.7).toStringAsFixed(1)} km',
          'distance': '${(distance - 1.7).toStringAsFixed(1)} km',
          'duration': '${duration - 5} min',
        },
      ],
    };
  }

  /// Get current location information
  @MCPResource('currentLocation', description: 'Current user location data')
  Future<MCPResourceContent> getCurrentLocation(String uri) async {
    // Mock current location
    final data = {
      'lat': 40.7128,
      'lng': -74.0060,
      'address': 'New York, NY, USA',
      'accuracy': 20,
      'timestamp': DateTime.now().toIso8601String(),
    };

    return MCPResourceContent(
      uri: uri,
      name: 'currentLocation',
      title: 'Current Location Data',
      description:
          'Real-time location information including coordinates and address',
      mimeType: 'application/json',
      text: jsonEncode(data),
      annotations: MCPResourceAnnotations(
        audience: ['user', 'assistant'],
        priority: 0.8,
        lastModified: DateTime.now().toIso8601String(),
      ),
    );
  }

  /// Get nearby points of interest
  @MCPTool('nearbySearch', description: 'Find nearby places of interest')
  Future<Map<String, dynamic>> nearbySearch(
    double lat,
    double lng, {
    int radius = 1000,
    String? type,
  }) async {
    await Future.delayed(Duration(milliseconds: 250));

    final places = [
      {
        'name': 'Central Coffee Shop',
        'type': 'cafe',
        'rating': 4.5,
        'distance': 150,
        'lat': lat + 0.001,
        'lng': lng + 0.001,
      },
      {
        'name': 'Quick Mart',
        'type': 'convenience_store',
        'rating': 3.8,
        'distance': 300,
        'lat': lat - 0.002,
        'lng': lng + 0.001,
      },
      {
        'name': 'Downtown Restaurant',
        'type': 'restaurant',
        'rating': 4.2,
        'distance': 450,
        'lat': lat + 0.003,
        'lng': lng - 0.002,
      },
    ];

    var filteredPlaces = places;
    if (type != null) {
      filteredPlaces = places.where((p) => p['type'] == type).toList();
    }

    return {
      'location': {'lat': lat, 'lng': lng},
      'radius': radius,
      'type': type,
      'places': filteredPlaces,
    };
  }

  /// Generate a location summary prompt
  @MCPPrompt('locationSummary', description: 'Generate a summary of a location')
  String locationSummaryPrompt(
    String location, {
    String summaryType = 'general',
  }) {
    switch (summaryType.toLowerCase()) {
      case 'tourist':
        return '''Please provide a tourist-friendly summary of $location, including:
- Main attractions and landmarks
- Best times to visit
- Local cuisine and dining recommendations
- Transportation options
- Cultural highlights and activities''';

      case 'business':
        return '''Please provide a business-focused summary of $location, including:
- Economic climate and key industries
- Business districts and commercial areas
- Transportation and logistics
- Cost of living and operating
- Networking opportunities''';

      default:
        return '''Please provide a comprehensive summary of $location, including:
- Geographic location and climate
- Population and demographics
- Key features and landmarks
- Transportation and accessibility
- Notable characteristics''';
    }
  }

  /// Get traffic information for a route
  @MCPTool('getTrafficInfo', description: 'Get current traffic information')
  Future<Map<String, dynamic>> getTrafficInfo(
    String origin,
    String destination,
  ) async {
    await Future.delayed(Duration(milliseconds: 100));

    final conditions = ['light', 'moderate', 'heavy'];
    final condition = conditions[Random().nextInt(conditions.length)];

    final baseTime = 15 + Random().nextInt(30);
    final trafficMultiplier = condition == 'light'
        ? 1.0
        : condition == 'moderate'
        ? 1.3
        : 1.7;

    return {
      'origin': origin,
      'destination': destination,
      'traffic_condition': condition,
      'estimated_time': {
        'without_traffic': '$baseTime min',
        'with_traffic': '${(baseTime * trafficMultiplier).round()} min',
      },
      'incidents': condition == 'heavy'
          ? [
              {
                'type': 'accident',
                'location': 'Highway 101 near Exit 23',
                'severity': 'moderate',
                'delay': '5-10 minutes',
              },
            ]
          : [],
      'alternative_routes': [
        {
          'name': 'Via Highway 280',
          'time': '${baseTime + 5} min',
          'distance': '2.3 km longer',
        },
      ],
    };
  }
}

final server = GoogleMapsMCP();

void main() async {
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
  server.showUsage();

  print('🗺️  Google Maps MCP Server');
  print(
    '📋 Available tools: searchPlace, getDirections, nearbySearch, getTrafficInfo',
  );
  print('📚 Available resources: currentLocation');
  print('💬 Available prompts: locationSummary');
  print('');

  await server.serve(port: 8080);
  await server.start();
}

void showHelp() => server.showUsage();
