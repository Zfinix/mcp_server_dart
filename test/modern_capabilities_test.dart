import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:mcp_server_dart/mcp_server_dart.dart';
import 'package:test/test.dart';

class ModernCapabilityServer extends MCPServer {
  ModernCapabilityServer()
    : super(
        name: 'modern-server',
        version: '1.2.0',
        description: 'Modern MCP capability test server',
        title: 'Modern MCP Test Server',
        instructions: 'Use the modern MCP features during testing.',
        websiteUrl: 'https://example.com/mcp',
        icons: const [
          MCPIcon(src: 'https://example.com/icon.png', mimeType: 'image/png'),
        ],
      ) {
    registerTool(
      'echo',
      (context) async => context.param<String>('text'),
      description: 'Echoes a string',
      inputSchema: {
        'type': 'object',
        'properties': {
          'text': {'type': 'string'},
        },
        'required': ['text'],
      },
      annotations: const MCPToolAnnotations(
        taskSupport: MCPTaskSupport.optional,
      ),
    );

    registerTool(
      'slow_echo',
      (context) async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return context.param<String>('text');
      },
      description: 'Echoes slowly',
      inputSchema: {
        'type': 'object',
        'properties': {
          'text': {'type': 'string'},
        },
        'required': ['text'],
      },
      annotations: const MCPToolAnnotations(
        taskSupport: MCPTaskSupport.optional,
      ),
    );

    registerPrompt(
      'review',
      (args) => 'Review ${args['language'] ?? 'unknown'} code',
      description: 'Review prompt',
      arguments: const [
        MCPPromptArgument(
          name: 'language',
          description: 'Language',
          required: true,
        ),
      ],
    );

    registerPromptCompletion('review', (request) async {
      final value = request.argument.value.toLowerCase();
      final suggestions = [
        'dart',
        'python',
        'javascript',
      ].where((item) => item.startsWith(value)).toList();
      return MCPCompletionResult(
        completion: MCPCompletionData(
          values: suggestions,
          total: suggestions.length,
          hasMore: false,
        ),
      );
    });
  }
}

void main() {
  group('Modern MCP capabilities', () {
    late ModernCapabilityServer server;
    late Logger attachedLogger;

    setUp(() {
      server = ModernCapabilityServer();
      attachedLogger = Logger('modern-capabilities-test.attached');
      server.attachLogger(attachedLogger);
    });

    tearDown(() async {
      await server.detachLogger();
    });

    test('initialize advertises richer metadata and capabilities', () async {
      final response = await server.handleRequest(
        MCPRequest(
          method: 'initialize',
          id: 'init-1',
          params: {
            'protocolVersion': '2025-11-25',
            'capabilities': {
              'roots': {'listChanged': true},
              'sampling': {},
              'elicitation': {'form': {}, 'url': {}},
              'tasks': {
                'requests': {
                  'sampling': {'createMessage': {}},
                  'elicitation': {'create': {}},
                },
              },
            },
            'clientInfo': {'name': 'test-client', 'version': '1.0.0'},
          },
        ),
      );

      expect(response.error, isNull);
      final result = response.result as Map<String, dynamic>;
      expect(result['protocolVersion'], equals('2025-11-25'));
      expect(result['capabilities']['logging'], equals({}));
      expect(result['capabilities']['completions'], equals({}));
      expect(result['capabilities']['tasks'], isNotNull);
      expect(result['serverInfo']['title'], equals('Modern MCP Test Server'));
      expect(
        result['serverInfo']['websiteUrl'],
        equals('https://example.com/mcp'),
      );
      expect(result['instructions'], contains('modern MCP features'));

      expect(server.lastClientCapabilities, isNotNull);
      expect(server.lastClientCapabilities!.roots, isTrue);
      expect(server.lastClientCapabilities!.sampling, isTrue);
      expect(server.lastClientCapabilities!.elicitation, isTrue);
    });

    test('notifications/initialized toggles clientInitialized', () async {
      expect(server.clientInitialized, isFalse);
      final response = await server.handleRequest(
        const MCPRequest(method: 'notifications/initialized'),
      );
      expect(response.error, isNull);
      expect(server.clientInitialized, isTrue);
    });

    test(
      'logging/setLevel updates log level and emitLogMessage sends notification',
      () async {
        final outbound = <Map<String, dynamic>>[];
        server.setOutboundMessageSink(outbound.add);

        final setLevelResponse = await server.handleRequest(
          MCPRequest(
            method: 'logging/setLevel',
            id: 'log-1',
            params: {'level': MCPLoggingLevel.error},
          ),
        );

        expect(setLevelResponse.error, isNull);
        expect(server.logLevel, equals(MCPLoggingLevel.error));

        server.emitLogMessage(MCPLoggingLevel.info, {'message': 'ignore me'});
        expect(outbound, isEmpty);

        server.emitLogMessage(MCPLoggingLevel.error, {
          'message': 'boom',
        }, logger: 'tests');
        expect(outbound, hasLength(1));
        expect(outbound.first['method'], equals('notifications/message'));
        expect(
          outbound.first['params']['level'],
          equals(MCPLoggingLevel.error),
        );
        expect(outbound.first['params']['logger'], equals('tests'));
      },
    );

    test(
      'completion/complete returns suggestions from registered provider',
      () async {
        final response = await server.handleRequest(
          MCPRequest(
            method: 'completion/complete',
            id: 'completion-1',
            params: {
              'ref': {'type': 'ref/prompt', 'name': 'review'},
              'argument': {'name': 'language', 'value': 'py'},
            },
          ),
        );

        expect(response.error, isNull);
        final result = response.result as Map<String, dynamic>;
        expect(result['completion']['values'], equals(['python']));
        expect(result['completion']['hasMore'], isFalse);
      },
    );

    test('attachLogger forwards Dart LogRecord events as MCP logs', () async {
      final outbound = <Map<String, dynamic>>[];
      final logger = Logger('modern-capabilities-test.logger');
      final previousRootLevel = Logger.root.level;
      Logger.root.level = Level.ALL;

      server.setOutboundMessageSink(outbound.add);
      server.attachLogger(logger);

      await server.handleRequest(
        MCPRequest(
          method: 'logging/setLevel',
          id: 'log-bridge-level',
          params: {'level': MCPLoggingLevel.notice},
        ),
      );

      logger.info('ignore me');
      logger.warning('bridge me');
      await Future<void>.delayed(Duration.zero);

      expect(outbound, hasLength(1));
      expect(outbound.single['method'], equals('notifications/message'));
      expect(
        outbound.single['params']['level'],
        equals(MCPLoggingLevel.warning),
      );
      expect(
        outbound.single['params']['logger'],
        equals('modern-capabilities-test.logger'),
      );
      expect(outbound.single['params']['data']['message'], equals('bridge me'));

      await server.detachLogger();
      Logger.root.level = previousRootLevel;
    });

    test('tasks create, get, list, and result flow works', () async {
      final createResponse = await server.handleRequest(
        MCPRequest(
          method: 'tools/call',
          id: 'task-create',
          params: {
            'name': 'slow_echo',
            'arguments': {'text': 'hello tasks'},
            'task': {'ttl': 2000},
          },
        ),
      );

      expect(createResponse.error, isNull);
      final createResult = createResponse.result as Map<String, dynamic>;
      final task = createResult['task'] as Map<String, dynamic>;
      final taskId = task['taskId'] as String;
      expect(task['status'], equals(MCPTaskStatus.working));

      final getResponse = await server.handleRequest(
        MCPRequest(
          method: 'tasks/get',
          id: 'task-get',
          params: {'taskId': taskId},
        ),
      );
      expect(getResponse.error, isNull);
      expect(
        (getResponse.result as Map<String, dynamic>)['taskId'],
        equals(taskId),
      );

      final listResponse = await server.handleRequest(
        const MCPRequest(method: 'tasks/list', id: 'task-list'),
      );
      expect(listResponse.error, isNull);
      final tasks =
          (listResponse.result as Map<String, dynamic>)['tasks']
              as List<dynamic>;
      expect(
        tasks.map((e) => (e as Map<String, dynamic>)['taskId']),
        contains(taskId),
      );

      final resultResponse = await server.handleRequest(
        MCPRequest(
          method: 'tasks/result',
          id: 'task-result',
          params: {'taskId': taskId},
        ),
      );
      expect(resultResponse.error, isNull);
      final result = resultResponse.result as Map<String, dynamic>;
      final content = result['content'] as List<dynamic>;
      expect(
        jsonDecode((content.first as Map<String, dynamic>)['text'] as String),
        equals('hello tasks'),
      );
    });

    test('tasks can be cancelled', () async {
      final createResponse = await server.handleRequest(
        MCPRequest(
          method: 'tools/call',
          id: 'cancel-create',
          params: {
            'name': 'slow_echo',
            'arguments': {'text': 'cancel me'},
            'task': {'ttl': 2000},
          },
        ),
      );
      final taskId =
          ((createResponse.result as Map<String, dynamic>)['task']
                  as Map<String, dynamic>)['taskId']
              as String;

      final cancelResponse = await server.handleRequest(
        MCPRequest(
          method: 'tasks/cancel',
          id: 'cancel-task',
          params: {'taskId': taskId},
        ),
      );
      expect(cancelResponse.error, isNull);
      expect(
        (cancelResponse.result as Map<String, dynamic>)['status'],
        equals(MCPTaskStatus.cancelled),
      );

      final resultResponse = await server.handleRequest(
        MCPRequest(
          method: 'tasks/result',
          id: 'cancel-result',
          params: {'taskId': taskId},
        ),
      );
      expect(resultResponse.error, isNotNull);
      expect(resultResponse.error!.message, contains('cancelled'));
    });

    test('client request helpers emit requests and accept responses', () async {
      final outbound = <Map<String, dynamic>>[];
      server.setOutboundMessageSink(outbound.add);

      final rootsFuture = server.listRoots();
      expect(outbound.single['method'], equals('roots/list'));
      final rootsRequestId = outbound.single['id'];
      await server.receiveMessage({
        'jsonrpc': '2.0',
        'id': rootsRequestId,
        'result': {
          'roots': [
            {'uri': 'file:///workspace', 'name': 'workspace'},
          ],
        },
      });
      final roots = await rootsFuture;
      expect(roots.roots.single.uri, equals('file:///workspace'));

      outbound.clear();
      final samplingFuture = server.requestSampling(
        const MCPSamplingRequest({
          'messages': [
            {
              'role': 'user',
              'content': {'type': 'text', 'text': 'Hi'},
            },
          ],
        }),
      );
      expect(outbound.single['method'], equals('sampling/createMessage'));
      final samplingRequestId = outbound.single['id'];
      await server.receiveMessage({
        'jsonrpc': '2.0',
        'id': samplingRequestId,
        'result': {
          'content': [
            {'type': 'text', 'text': 'Hello back'},
          ],
        },
      });
      final samplingResponse = await samplingFuture;
      expect(
        (samplingResponse.result as Map<String, dynamic>)['content'],
        isNotEmpty,
      );

      outbound.clear();
      final elicitationFuture = server.requestElicitation(
        MCPElicitationRequest.form(
          message: 'Need more info',
          requestedSchema: {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
            },
          },
        ),
      );
      expect(outbound.single['method'], equals('elicitation/create'));
      final elicitationRequestId = outbound.single['id'];
      await server.receiveMessage({
        'jsonrpc': '2.0',
        'id': elicitationRequestId,
        'result': {
          'action': 'accept',
          'content': {'name': 'Ada'},
        },
      });
      final elicitationResponse = await elicitationFuture;
      expect(
        (elicitationResponse.result as Map<String, dynamic>)['action'],
        equals('accept'),
      );
    });
  });
}
