/// Weather Service MCP Server (Generated Example)
///
/// Demonstrates:
/// - Annotation-based tool registration
/// - Code generation with build_runner
/// - Complex data structures
/// - External API simulation
library;

import 'dart:math';
import 'package:logging/logging.dart';
import 'package:dart_mcp/dart_mcp.dart';

part 'weather_service.g.dart';

/// Weather conditions enum
enum WeatherCondition { sunny, cloudy, rainy, snowy, stormy, foggy }

/// Weather Service MCP Server with annotations
class WeatherServiceMCP extends MCPServer {
  WeatherServiceMCP()
    : super(
        name: 'weather-service-mcp',
        version: '1.0.0',
        description: 'A weather service MCP server using annotations',
      );

  @MCPTool(
    'get_current_weather',
    description: 'Get current weather for a location',
  )
  Future<Map<String, dynamic>> getCurrentWeather(
    @MCPParam(description: 'City name or coordinates', example: 'San Francisco')
    String location, {
    @MCPParam(
      required: false,
      description: 'Temperature unit',
      example: 'celsius',
    )
    String unit = 'celsius',
    @MCPParam(required: false, description: 'Include extended forecast')
    bool includeExtended = false,
  }) async {
    // Simulate API call delay
    await Future.delayed(Duration(milliseconds: 200));

    final random = Random();
    final conditions = WeatherCondition.values;
    final condition = conditions[random.nextInt(conditions.length)];

    final baseTemp = unit == 'fahrenheit' ? 70 : 20;
    final temperature = baseTemp + random.nextInt(20) - 10;

    final result = {
      'location': location,
      'temperature': temperature,
      'unit': unit == 'fahrenheit' ? '°F' : '°C',
      'condition': condition.name,
      'humidity': 30 + random.nextInt(40),
      'wind_speed': random.nextInt(25),
      'wind_direction': [
        'N',
        'NE',
        'E',
        'SE',
        'S',
        'SW',
        'W',
        'NW',
      ][random.nextInt(8)],
      'pressure': 1000 + random.nextInt(50),
      'visibility': 5 + random.nextInt(15),
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (includeExtended) {
      result['forecast'] = List.generate(5, (index) {
        final futureDate = DateTime.now().add(Duration(days: index + 1));
        return {
          'date': futureDate.toIso8601String().split('T')[0],
          'temperature_high': temperature + random.nextInt(10) - 5,
          'temperature_low': temperature - random.nextInt(10),
          'condition': conditions[random.nextInt(conditions.length)].name,
          'precipitation_chance': random.nextInt(100),
        };
      });
    }

    return result;
  }

  @MCPTool(
    'get_weather_alerts',
    description: 'Get weather alerts for a location',
  )
  Future<List<Map<String, dynamic>>> getWeatherAlerts(
    @MCPParam(description: 'Location to check for alerts') String location, {
    @MCPParam(required: false, description: 'Alert severity filter')
    String? severity,
  }) async {
    await Future.delayed(Duration(milliseconds: 100));

    final random = Random();
    final alerts = <Map<String, dynamic>>[];

    // Randomly generate alerts
    if (random.nextBool()) {
      final severities = ['minor', 'moderate', 'severe', 'extreme'];
      final alertSeverity = severities[random.nextInt(severities.length)];

      if (severity == null || severity == alertSeverity) {
        alerts.add({
          'id': 'ALERT_${random.nextInt(10000)}',
          'title': 'Weather Advisory',
          'severity': alertSeverity,
          'description':
              'Weather conditions may impact travel and outdoor activities.',
          'start_time': DateTime.now().toIso8601String(),
          'end_time': DateTime.now().add(Duration(hours: 6)).toIso8601String(),
          'areas': [location],
        });
      }
    }

    return alerts;
  }

  @MCPTool('search_locations', description: 'Search for weather locations')
  Future<List<Map<String, dynamic>>> searchLocations(
    @MCPParam(description: 'Search query for locations') String query, {
    @MCPParam(required: false, description: 'Maximum number of results')
    int limit = 10,
  }) async {
    await Future.delayed(Duration(milliseconds: 150));

    final mockLocations = [
      {
        'name': '$query City',
        'country': 'US',
        'lat': 37.7749,
        'lon': -122.4194,
      },
      {
        'name': '$query Beach',
        'country': 'US',
        'lat': 33.7701,
        'lon': -118.1937,
      },
      {
        'name': '$query Valley',
        'country': 'CA',
        'lat': 49.2827,
        'lon': -123.1207,
      },
      {'name': 'New $query', 'country': 'UK', 'lat': 51.5074, 'lon': -0.1278},
      {
        'name': '$query Heights',
        'country': 'AU',
        'lat': -33.8688,
        'lon': 151.2093,
      },
    ];

    return mockLocations.take(limit).toList();
  }

  @MCPResource(
    'weather_stations',
    description: 'Available weather monitoring stations',
    mimeType: 'application/json',
  )
  Future<MCPResourceContent> getWeatherStations(String uri) async {
    final stations = {
      'stations': [
        {
          'id': 'WS001',
          'name': 'Downtown Station',
          'location': {'lat': 37.7749, 'lon': -122.4194},
          'elevation': 52,
          'status': 'active',
          'last_updated': DateTime.now()
              .subtract(Duration(minutes: 5))
              .toIso8601String(),
        },
        {
          'id': 'WS002',
          'name': 'Airport Station',
          'location': {'lat': 37.6213, 'lon': -122.3790},
          'elevation': 4,
          'status': 'active',
          'last_updated': DateTime.now()
              .subtract(Duration(minutes: 3))
              .toIso8601String(),
        },
        {
          'id': 'WS003',
          'name': 'Mountain Station',
          'location': {'lat': 37.8044, 'lon': -122.2712},
          'elevation': 380,
          'status': 'maintenance',
          'last_updated': DateTime.now()
              .subtract(Duration(hours: 2))
              .toIso8601String(),
        },
      ],
      'total_count': 3,
      'active_count': 2,
    };

    return MCPResourceContent(
      uri: uri,
      name: 'weather_stations',
      title: 'Weather Monitoring Stations',
      description:
          'Available weather monitoring stations with real-time status',
      mimeType: 'application/json',
      text: jsonEncode(stations),
      annotations: MCPResourceAnnotations(
        audience: ['user', 'assistant'],
        priority: 0.9,
        lastModified: DateTime.now().toIso8601String(),
      ),
    );
  }

  @MCPPrompt(
    'weather_report',
    description: 'Generate weather report templates',
    arguments: ['location', 'format', 'audience'],
  )
  String weatherReportPrompt(Map<String, dynamic> args) {
    final location = args['location'] ?? 'your area';
    final format = args['format'] ?? 'detailed';
    final audience = args['audience'] ?? 'general';

    return '''Generate a $format weather report for $location targeted at $audience audience.

**Location:** $location
**Format:** $format
**Target Audience:** $audience

Please include:
- Current weather conditions with specific details
- Temperature trends and comfort levels
- Precipitation probability and timing
- Wind conditions and their impact
- Visibility and air quality information
- Weather alerts or advisories if applicable
- Recommendations for outdoor activities
- Appropriate clothing suggestions
- Travel conditions and safety considerations

Format the report in a clear, engaging style appropriate for the $audience audience.
Use professional meteorological terminology when suitable, but ensure accessibility.
''';
  }
}

void main(List<String> args) async {
  // Setup logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final server = WeatherServiceMCP();

  // This would be generated by build_runner
  // server.registerGeneratedHandlers();

  // For now, we'll register manually since this is an example
  server.registerTool(
    'get_current_weather',
    (context) => server.getCurrentWeather(
      context.param<String>('location'),
      unit: context.optionalParam<String>('unit') ?? 'celsius',
      includeExtended: context.optionalParam<bool>('includeExtended') ?? false,
    ),
  );

  server.registerTool(
    'get_weather_alerts',
    (context) => server.getWeatherAlerts(
      context.param<String>('location'),
      severity: context.optionalParam<String>('severity'),
    ),
  );

  server.registerTool(
    'search_locations',
    (context) => server.searchLocations(
      context.param<String>('query'),
      limit: context.optionalParam<int>('limit') ?? 10,
    ),
  );

  server.registerResource('weather_stations', server.getWeatherStations);
  server.registerPrompt('weather_report', server.weatherReportPrompt);

  print('🌤️  Weather Service MCP Server');
  print(
    '📋 Available tools: get_current_weather, get_weather_alerts, search_locations',
  );
  print('📚 Available resources: weather_stations');
  print('💬 Available prompts: weather_report');
  print('');

  // Handle command line arguments
  if (args.contains('--help') || args.contains('-h')) {
    print('Usage: dart weather_service.dart [options]');
    print('');
    print('Options:');
    print('  --stdio        Start server in stdio mode (default)');
    print('  --http         Start HTTP server on port 8080');
    print('  --port <port>  Specify HTTP port (default: 8080)');
    print('  --help, -h     Show this help message');
    return;
  }

  if (args.contains('--http')) {
    final port = args.contains('--port')
        ? int.parse(args[args.indexOf('--port') + 1])
        : 8080;

    print('🌐 Starting HTTP server on port $port...');
    print('🔍 Health check: http://localhost:$port/health');
    print('📊 Status: http://localhost:$port/status');
    print('');

    await server.serve(port: port);
  } else {
    print('🔌 Starting MCP server on stdio...');
    print('💡 Tip: Use --http flag to start HTTP server instead');
    print(
      '💡 Note: Run "dart run build_runner build" to generate registration code',
    );
    print('');

    await server.start();
  }
}
