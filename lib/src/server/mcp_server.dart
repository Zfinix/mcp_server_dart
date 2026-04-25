/// Base MCP Server implementation
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

import 'package:mcp_server_dart/src/protocol/types.dart';
import 'http_handlers.dart';
import 'middleware.dart';
import 'session_manager.dart';
import 'server_utils.dart';

export 'package:mcp_server_dart/src/protocol/types.dart'
    show MCPResourceContent;

typedef MCPToolHandler = Future<Object?> Function(MCPToolContext context);
typedef MCPResourceHandler = Future<MCPResourceContent> Function(String uri);
typedef MCPPromptHandler = String Function(Map<String, Object?> args);
typedef MCPCompletionHandler =
    FutureOr<MCPCompletionResult> Function(MCPCompletionRequest request);

typedef OutboundMessageSink = void Function(Map<String, dynamic> message);

abstract class MCPServer {
  final Logger _logger = Logger('MCPServer');

  final Map<String, MCPToolDefinition> _tools = {};
  final Map<String, MCPToolHandler> _toolHandlers = {};

  final Map<String, MCPResourceDefinition> _resources = {};
  final Map<String, MCPResourceHandler> _resourceHandlers = {};

  final Map<String, MCPPromptDefinition> _prompts = {};
  final Map<String, MCPPromptHandler> _promptHandlers = {};

  final Map<String, MCPCompletionHandler> _promptCompletionHandlers = {};
  final Map<String, MCPCompletionHandler> _resourceCompletionHandlers = {};

  final String name;
  final String version;
  final String? description;
  final String protocolVersion;
  final String? title;
  final String? instructions;
  final String? websiteUrl;
  final List<MCPIcon>? icons;

  final bool enableLogging;
  final bool enableCompletions;
  final bool enableTasks;
  final MCPTasksCapability? taskCapabilities;
  final Map<String, dynamic>? experimentalCapabilities;
  final Duration defaultTaskTtl;
  final Duration defaultTaskPollInterval;

  final List<String> allowedOrigins;
  final bool validateOrigins;
  final bool allowLocalhost;
  final Set<String> allowedHeaders;

  final bool _authEnabled;
  final TokenValidator _tokenValidator;

  final Set<RelicWebSocket> _activeConnections = <RelicWebSocket>{};
  RelicServer? _server;
  Timer? _connectionMonitor;
  late final DateTime _startTime;

  late final SessionManager _sessionManager;
  late final HttpHandlers _httpHandlers;

  final StreamController<Map<String, dynamic>> _outboundMessagesController =
      StreamController<Map<String, dynamic>>.broadcast(sync: true);
  OutboundMessageSink? _outboundMessageSink;
  final Map<Object, Completer<MCPResponse>> _pendingClientRequests = {};
  int _nextClientRequestId = 1;
  MCPClientCapabilities? lastClientCapabilities;
  bool clientInitialized = false;
  String _logLevel = MCPLoggingLevel.info;
  StreamSubscription<LogRecord>? _attachedLogSubscription;

  final Map<String, _ServerTask> _tasks = {};

  MCPServer({
    required this.name,
    this.version = '1.0.0',
    this.protocolVersion = '2025-11-25',
    this.description,
    this.title,
    this.instructions,
    this.websiteUrl,
    this.icons,
    this.enableLogging = false,
    this.enableCompletions = false,
    this.enableTasks = false,
    this.taskCapabilities,
    this.experimentalCapabilities,
    this.defaultTaskTtl = const Duration(minutes: 5),
    this.defaultTaskPollInterval = const Duration(milliseconds: 250),
    this.allowedOrigins = const [],
    this.validateOrigins = false,
    this.allowLocalhost = true,
    this.allowedHeaders = const {},
    bool enableAuth = false,
    TokenValidator? tokenValidator,
  }) : _authEnabled = enableAuth,
       _tokenValidator = tokenValidator ?? defaultTokenValidator {
    _sessionManager = SessionManager();
    _startTime = DateTime.now();
    _httpHandlers = HttpHandlers(
      serverName: name,
      serverVersion: version,
      serverProtocolVersion: protocolVersion,
      serverDescription: description,
      startTime: _startTime,
      validateOrigins: validateOrigins,
      allowLocalhost: allowLocalhost,
      allowedOrigins: allowedOrigins,
      allowedHeaders: allowedHeaders,
      tools: _tools,
      resources: _resources,
      prompts: _prompts,
      activeConnections: _activeConnections,
      handleRequest: handleRequest,
      sessionManager: _sessionManager,
      authEnabled: _authEnabled,
      validateToken: _tokenValidator,
    );
  }

  Stream<Map<String, dynamic>> get outboundMessages =>
      _outboundMessagesController.stream;

  String get logLevel => _logLevel;

  bool get supportsLogging => enableLogging || _attachedLogSubscription != null;

  bool get supportsCompletions =>
      enableCompletions ||
      _promptCompletionHandlers.isNotEmpty ||
      _resourceCompletionHandlers.isNotEmpty;

  bool get supportsTasks =>
      enableTasks ||
      _tools.values.any((tool) => tool.annotations?.taskSupport != null);

  void setOutboundMessageSink(OutboundMessageSink? sink) {
    _outboundMessageSink = sink;
  }

  void registerTool(
    String name,
    MCPToolHandler handler, {
    String description = '',
    String? title,
    Map<String, Object?>? inputSchema,
    MCPToolAnnotations? annotations,
    List<MCPIcon>? icons,
  }) {
    _tools[name] = MCPToolDefinition(
      name: name,
      description: description,
      title: title,
      inputSchema: inputSchema == null
          ? null
          : Map<String, dynamic>.from(inputSchema),
      annotations: annotations,
      icons: icons,
    );
    _toolHandlers[name] = handler;
    _logger.info('Registered tool: $name');
  }

  void registerResource(
    String name,
    MCPResourceHandler handler, {
    String description = '',
    String? title,
    String? mimeType,
    List<MCPIcon>? icons,
  }) {
    final uri = 'mcp://$name';
    _resources[uri] = MCPResourceDefinition(
      uri: uri,
      name: name,
      description: description,
      title: title,
      mimeType: mimeType,
      icons: icons,
    );
    _resourceHandlers[uri] = handler;
    _logger.info('Registered resource: $name');
  }

  void registerPrompt(
    String name,
    MCPPromptHandler handler, {
    String description = '',
    String? title,
    List<MCPPromptArgument>? arguments,
    List<MCPIcon>? icons,
  }) {
    _prompts[name] = MCPPromptDefinition(
      name: name,
      description: description,
      title: title,
      arguments: arguments,
      icons: icons,
    );
    _promptHandlers[name] = handler;
    _logger.info('Registered prompt: $name');
  }

  void registerPromptCompletion(
    String promptName,
    MCPCompletionHandler handler,
  ) {
    _promptCompletionHandlers[promptName] = handler;
  }

  void registerResourceCompletion(
    String resourceUri,
    MCPCompletionHandler handler,
  ) {
    _resourceCompletionHandlers[resourceUri] = handler;
  }

  /// Attach a Dart [Logger] so its [LogRecord] events are forwarded as
  /// MCP `notifications/message` logging notifications.
  ///
  /// Call this during bootstrap, after constructing the server and before
  /// calling [start] or [serve]. Re-attaching replaces the previous bridge.
  void attachLogger(Logger logger) {
    _attachedLogSubscription?.cancel();
    _attachedLogSubscription = logger.onRecord.listen((record) {
      emitLogMessage(_mapDartLogLevel(record.level), {
        'message': record.message,
        if (record.error != null) 'error': '${record.error}',
        if (record.stackTrace != null) 'stackTrace': '${record.stackTrace}',
        'time': record.time.toIso8601String(),
        'sequenceNumber': record.sequenceNumber,
      }, logger: record.loggerName);
    });
  }

  Future<void> detachLogger() async {
    await _attachedLogSubscription?.cancel();
    _attachedLogSubscription = null;
  }

  Future<MCPResponse> handleRequest(MCPRequest request) async {
    try {
      return switch (request.method) {
        'initialize' => _handleInitialize(request),
        'notifications/initialized' => _handleInitializedNotification(request),
        'tools/list' => _handleToolsList(request),
        'tools/call' => await _handleToolCall(request),
        'resources/list' => _handleResourcesList(request),
        'resources/read' => await _handleResourceRead(request),
        'prompts/list' => _handlePromptsList(request),
        'prompts/get' => _handlePromptGet(request),
        'logging/setLevel' => _handleLoggingSetLevel(request),
        'completion/complete' => await _handleCompletionComplete(request),
        'tasks/get' => _handleTaskGet(request),
        'tasks/result' => await _handleTaskResult(request),
        'tasks/list' => _handleTaskList(request),
        'tasks/cancel' => _handleTaskCancel(request),
        'ping' => _handlePing(request),
        _ => _errorResponse(
          request.id,
          -32601,
          'Method not found: ${request.method}',
        ),
      };
    } catch (e, stackTrace) {
      _logger.severe('Error handling request: $e', e, stackTrace);
      return _internalError(request.id, e);
    }
  }

  Future<MCPResponse?> receiveMessage(Map<String, dynamic> json) async {
    if (json.containsKey('method')) {
      final request = MCPRequest.fromJson(json);
      final response = await handleRequest(request);
      return request.id != null ? response : null;
    }

    if (json.containsKey('id')) {
      final response = MCPResponse.fromJson(json);
      final completer = _pendingClientRequests.remove(response.id);
      if (completer != null && !completer.isCompleted) {
        completer.complete(response);
      }
    }

    return null;
  }

  Future<MCPResponse> sendClientRequest(
    String method,
    Map<String, dynamic> params,
  ) {
    final requestId = _nextClientRequestId++;
    final completer = Completer<MCPResponse>();
    _pendingClientRequests[requestId] = completer;
    _emitOutboundMessage(
      MCPRequest(method: method, id: requestId, params: params).toJson(),
    );
    return completer.future;
  }

  Future<MCPRootsListResult> listRoots() async {
    final response = await sendClientRequest('roots/list', const {});
    if (response.error != null) {
      throw StateError(response.error!.message);
    }
    return MCPRootsListResult.fromJson(
      Map<String, dynamic>.from(response.result as Map),
    );
  }

  Future<MCPResponse> requestSampling(MCPSamplingRequest request) {
    return sendClientRequest('sampling/createMessage', request.toJson());
  }

  Future<MCPResponse> requestElicitation(MCPElicitationRequest request) {
    return sendClientRequest('elicitation/create', request.toJson());
  }

  void emitNotification(String method, Map<String, dynamic> params) {
    _emitOutboundMessage({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    });
  }

  void emitLogMessage(String level, Object? data, {String? logger}) {
    if (!supportsLogging) return;
    if (!_shouldEmitLog(level)) return;
    _emitOutboundMessage(
      MCPLogMessageNotification(
        level: level,
        logger: logger,
        data: data,
      ).toJson(),
    );
  }

  MCPResponse _successResponse(Object? id, Map<String, dynamic> result) {
    return MCPResponse(id: id, result: result);
  }

  MCPResponse _errorResponse(
    Object? id,
    int code,
    String message, [
    dynamic data,
  ]) {
    return MCPResponse(
      id: id,
      error: MCPError(code: code, message: message, data: data),
    );
  }

  MCPResponse _internalError(Object? id, Object error) {
    return _errorResponse(id, -32603, 'Internal error: $error');
  }

  MCPResponse _missingParamsError(Object? id) {
    return _errorResponse(id, -32602, 'Missing parameters');
  }

  Map<String, dynamic>? _requireParams(MCPRequest request) => request.params;

  String? _requireStringParam(Map<String, dynamic> params, String key) {
    return params[key] as String?;
  }

  MCPResponse _handleInitialize(MCPRequest request) {
    final params = request.params ?? const {};
    final rawCapabilities = params['capabilities'];
    if (rawCapabilities is Map) {
      lastClientCapabilities = MCPClientCapabilities.fromJson(
        Map<String, dynamic>.from(rawCapabilities),
      );
    }

    final result = MCPInitializeResult(
      protocolVersion: protocolVersion,
      capabilities: _buildServerCapabilities(),
      serverInfo: MCPImplementationInfo(
        name: name,
        title: title,
        version: version,
        description: description,
        websiteUrl: websiteUrl,
        icons: icons,
      ),
      instructions: instructions,
    );

    return _successResponse(request.id, result.toJson());
  }

  MCPResponse _handleInitializedNotification(MCPRequest request) {
    clientInitialized = true;
    return _successResponse(request.id, const {});
  }

  MCPServerCapabilities _buildServerCapabilities() {
    final tasks = supportsTasks
        ? (taskCapabilities ??
              const MCPTasksCapability(
                list: true,
                cancel: true,
                toolsCall: true,
              ))
        : null;
    return MCPServerCapabilities(
      logging: supportsLogging,
      completions: supportsCompletions,
      prompts: const MCPListChangedCapability(listChanged: false),
      resources: const MCPResourceCapabilities(
        subscribe: false,
        listChanged: false,
      ),
      tools: const MCPListChangedCapability(listChanged: false),
      tasks: tasks,
      experimental: experimentalCapabilities,
    );
  }

  MCPResponse _handlePing(MCPRequest request) {
    return _successResponse(request.id, {
      'status': 'ok',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  MCPResponse _handleToolsList(MCPRequest request) {
    return _successResponse(request.id, {
      'tools': _tools.values.map((tool) => tool.toJson()).toList(),
    });
  }

  Future<MCPResponse> _handleToolCall(MCPRequest request) async {
    final params = _requireParams(request);
    if (params == null) {
      return _missingParamsError(request.id);
    }

    final toolName = _requireStringParam(params, 'name');
    if (toolName == null) {
      return _errorResponse(request.id, -32602, 'Missing tool name');
    }

    final toolDefinition = _tools[toolName];
    final handler = _toolHandlers[toolName];
    if (toolDefinition == null || handler == null) {
      return _errorResponse(request.id, -32601, 'Tool not found: $toolName');
    }

    final taskSupport =
        toolDefinition.annotations?.taskSupport ??
        (enableTasks ? MCPTaskSupport.optional : MCPTaskSupport.forbidden);
    final taskParams = params['task'];
    final taskRequested = taskParams is Map;

    if (taskSupport == MCPTaskSupport.required && !taskRequested) {
      return _errorResponse(
        request.id,
        -32600,
        'Task augmentation is required for tool: $toolName',
      );
    }

    if (taskRequested && !supportsTasks) {
      return _errorResponse(
        request.id,
        -32601,
        'Tasks are not supported by this server',
      );
    }

    if (taskRequested && taskSupport == MCPTaskSupport.forbidden) {
      return _errorResponse(
        request.id,
        -32602,
        'Task augmentation is forbidden for tool: $toolName',
      );
    }

    final rawArguments = params['arguments'];
    final arguments = rawArguments is Map
        ? Map<String, Object?>.from(rawArguments)
        : <String, Object?>{};

    if (taskRequested) {
      final taskMeta = MCPTaskMetadata.fromJson(
        Map<String, dynamic>.from(taskParams),
      );
      return _createTaskForToolCall(request, toolName, arguments, taskMeta);
    }

    return _executeToolCall(
      request.id,
      toolName,
      arguments,
      headers: request.headers,
    );
  }

  Future<MCPResponse> _executeToolCall(
    Object? requestId,
    String toolName,
    Map<String, Object?> arguments, {
    Map<String, String>? headers,
  }) async {
    final handler = _toolHandlers[toolName];
    if (handler == null) {
      return _errorResponse(requestId, -32601, 'Tool not found: $toolName');
    }

    try {
      final context = MCPToolContext(
        Map<String, dynamic>.from(arguments),
        toolName,
        requestId,
        headers: headers,
      );
      final result = await handler(context);

      if (result is MCPToolResult) {
        return _successResponse(requestId, {
          'content': _resultToContent(result.content),
          if (result.structuredContent != null)
            'structuredContent': result.structuredContent,
          if (result.resourceLinks != null)
            'resourceLinks': result.resourceLinks!
                .map((link) => link.toJson())
                .toList(),
          if (result.isError) 'isError': true,
        });
      }

      final content = _resultToContent(result);
      return _successResponse(requestId, {'content': content});
    } catch (e) {
      return _errorResponse(requestId, -32603, 'Tool execution error: $e');
    }
  }

  Future<MCPResponse> _createTaskForToolCall(
    MCPRequest request,
    String toolName,
    Map<String, Object?> arguments,
    MCPTaskMetadata taskMetadata,
  ) async {
    final taskId =
        'task_${DateTime.now().millisecondsSinceEpoch}_${_tasks.length + 1}';
    final now = DateTime.now().toUtc();
    final ttl = taskMetadata.ttl ?? defaultTaskTtl;
    final task = _ServerTask(
      taskId: taskId,
      toolName: toolName,
      status: MCPTaskStatus.working,
      createdAt: now,
      lastUpdatedAt: now,
      ttl: ttl,
      pollInterval: defaultTaskPollInterval,
      arguments: Map<String, Object?>.from(arguments),
      headers: request.headers,
    );
    _tasks[taskId] = task;

    unawaited(_runTask(task));
    _emitTaskStatus(task);

    return _successResponse(
      request.id,
      MCPCreateTaskResult(
        task: task.toPublicState().copyWith(statusMessage: 'Task accepted'),
      ).toJson(),
    );
  }

  Future<void> _runTask(_ServerTask task) async {
    try {
      final response = await _executeToolCall(
        null,
        task.toolName,
        task.arguments,
        headers: task.headers,
      );
      if (task.status == MCPTaskStatus.cancelled) {
        return;
      }
      if (response.error != null) {
        task.status = MCPTaskStatus.failed;
        task.error = response.error;
        task.statusMessage = response.error!.message;
      } else {
        task.status = MCPTaskStatus.completed;
        task.result = response.result;
      }
      task.lastUpdatedAt = DateTime.now().toUtc();
      _emitTaskStatus(task);
      if (!task.completer.isCompleted) {
        task.completer.complete();
      }
    } catch (e) {
      if (task.status == MCPTaskStatus.cancelled) {
        return;
      }
      task.status = MCPTaskStatus.failed;
      task.error = MCPError(code: -32603, message: 'Task failed: $e');
      task.statusMessage = 'Task failed: $e';
      task.lastUpdatedAt = DateTime.now().toUtc();
      _emitTaskStatus(task);
      if (!task.completer.isCompleted) {
        task.completer.complete();
      }
    }
  }

  void _emitTaskStatus(_ServerTask task) {
    if (!supportsTasks) return;
    emitNotification('notifications/tasks/status', {
      'taskId': task.taskId,
      'status': task.status,
      if (task.statusMessage != null) 'statusMessage': task.statusMessage,
    });
  }

  List<Map<String, dynamic>> _resultToContent(Object? result) {
    if (result is List<MCPContent>) {
      return result.map((c) => c.toJson()).toList();
    }

    if (result is MCPContent) {
      return [result.toJson()];
    }

    // String tools already return serialized JSON — use as-is.
    if (result is String) {
      return [
        {'type': 'text', 'text': result},
      ];
    }

    return [
      {'type': 'text', 'text': jsonEncode(result)},
    ];
  }

  MCPResponse _handleResourcesList(MCPRequest request) {
    return _successResponse(request.id, {
      'resources': _resources.values
          .map((resource) => resource.toJson())
          .toList(),
    });
  }

  Future<MCPResponse> _handleResourceRead(MCPRequest request) async {
    final params = _requireParams(request);
    if (params == null) {
      return _missingParamsError(request.id);
    }

    final uri = _requireStringParam(params, 'uri');
    if (uri == null) {
      return _errorResponse(request.id, -32602, 'Missing resource URI');
    }

    final handler = _resourceHandlers[uri];
    if (handler == null) {
      return _errorResponse(request.id, -32601, 'Resource not found: $uri');
    }

    try {
      final content = await handler(uri);
      return _successResponse(request.id, {
        'contents': [content.toJson()],
      });
    } catch (e) {
      return _errorResponse(request.id, -32603, 'Resource read error: $e');
    }
  }

  MCPResponse _handlePromptsList(MCPRequest request) {
    return _successResponse(request.id, {
      'prompts': _prompts.values.map((prompt) => prompt.toJson()).toList(),
    });
  }

  MCPResponse _handlePromptGet(MCPRequest request) {
    final params = _requireParams(request);
    if (params == null) {
      return _missingParamsError(request.id);
    }

    final promptName = _requireStringParam(params, 'name');
    if (promptName == null) {
      return _errorResponse(request.id, -32602, 'Missing prompt name');
    }

    final handler = _promptHandlers[promptName];
    if (handler == null) {
      return _errorResponse(
        request.id,
        -32601,
        'Prompt not found: $promptName',
      );
    }

    try {
      final rawArguments = params['arguments'];
      final arguments = rawArguments is Map
          ? Map<String, Object?>.from(rawArguments)
          : <String, Object?>{};
      final result = handler(arguments);

      return _successResponse(request.id, {
        'description': _prompts[promptName]?.description ?? '',
        'messages': [
          {
            'role': 'user',
            'content': {'type': 'text', 'text': result},
          },
        ],
      });
    } catch (e) {
      return _errorResponse(request.id, -32603, 'Prompt execution error: $e');
    }
  }

  MCPResponse _handleLoggingSetLevel(MCPRequest request) {
    if (!supportsLogging) {
      return _errorResponse(request.id, -32601, 'Logging not supported');
    }
    final params = _requireParams(request);
    if (params == null) {
      return _missingParamsError(request.id);
    }
    final level = _requireStringParam(params, 'level');
    if (level == null || !MCPLoggingLevel.isValid(level)) {
      return _errorResponse(request.id, -32602, 'Invalid log level');
    }
    _logLevel = level;
    return _successResponse(request.id, const {});
  }

  Future<MCPResponse> _handleCompletionComplete(MCPRequest request) async {
    if (!supportsCompletions) {
      return _errorResponse(request.id, -32601, 'Completions not supported');
    }
    final params = _requireParams(request);
    if (params == null) {
      return _missingParamsError(request.id);
    }

    try {
      final completionRequest = MCPCompletionRequest.fromJson(params);
      final ref = completionRequest.ref;
      final handler = switch (ref.type) {
        'ref/prompt' =>
          ref.name != null ? _promptCompletionHandlers[ref.name!] : null,
        'ref/resource' =>
          ref.uri != null ? _resourceCompletionHandlers[ref.uri!] : null,
        _ => null,
      };

      if (handler == null) {
        return _errorResponse(
          request.id,
          -32601,
          'No completion provider found for ${ref.type}',
        );
      }

      final result = await handler(completionRequest);
      return _successResponse(request.id, result.toJson());
    } catch (e) {
      return _errorResponse(request.id, -32603, 'Completion error: $e');
    }
  }

  MCPResponse _handleTaskGet(MCPRequest request) {
    if (!supportsTasks) {
      return _errorResponse(request.id, -32601, 'Tasks not supported');
    }
    final params = _requireParams(request);
    if (params == null) {
      return _missingParamsError(request.id);
    }
    final taskId = _requireStringParam(params, 'taskId');
    if (taskId == null) {
      return _errorResponse(request.id, -32602, 'Missing taskId');
    }
    final task = _tasks[taskId];
    if (task == null) {
      return _errorResponse(request.id, -32602, 'Unknown taskId: $taskId');
    }
    return _successResponse(request.id, task.toPublicState().toJson());
  }

  Future<MCPResponse> _handleTaskResult(MCPRequest request) async {
    if (!supportsTasks) {
      return _errorResponse(request.id, -32601, 'Tasks not supported');
    }
    final params = _requireParams(request);
    if (params == null) {
      return _missingParamsError(request.id);
    }
    final taskId = _requireStringParam(params, 'taskId');
    if (taskId == null) {
      return _errorResponse(request.id, -32602, 'Missing taskId');
    }
    final task = _tasks[taskId];
    if (task == null) {
      return _errorResponse(request.id, -32602, 'Unknown taskId: $taskId');
    }

    if (!MCPTaskStatus.terminal.contains(task.status)) {
      await task.completer.future;
    }

    if (task.status == MCPTaskStatus.cancelled) {
      return _errorResponse(request.id, -32602, 'Task was cancelled');
    }

    if (task.error != null) {
      return MCPResponse(id: request.id, error: task.error);
    }

    final result = task.result;
    if (result is Map<String, dynamic>) {
      return _successResponse(request.id, result);
    }
    return _successResponse(request.id, {
      'task': task.toPublicState().toJson(),
      'result': result,
    });
  }

  MCPResponse _handleTaskList(MCPRequest request) {
    if (!supportsTasks) {
      return _errorResponse(request.id, -32601, 'Tasks not supported');
    }
    final params = request.params ?? const {};
    final cursor = params['cursor'] as String?;
    final limit = params['limit'] is int ? params['limit'] as int : 20;
    final offset = int.tryParse(cursor ?? '0') ?? 0;

    final tasks = _tasks.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final start = offset.clamp(0, tasks.length);
    final end = (start + limit).clamp(0, tasks.length);
    final page = tasks
        .sublist(start, end)
        .map((task) => task.toPublicState())
        .toList();
    final nextCursor = end < tasks.length ? '$end' : null;

    return _successResponse(
      request.id,
      MCPTaskListResult(tasks: page, nextCursor: nextCursor).toJson(),
    );
  }

  MCPResponse _handleTaskCancel(MCPRequest request) {
    if (!supportsTasks) {
      return _errorResponse(request.id, -32601, 'Tasks not supported');
    }
    final params = _requireParams(request);
    if (params == null) {
      return _missingParamsError(request.id);
    }
    final taskId = _requireStringParam(params, 'taskId');
    if (taskId == null) {
      return _errorResponse(request.id, -32602, 'Missing taskId');
    }
    final task = _tasks[taskId];
    if (task == null) {
      return _errorResponse(request.id, -32602, 'Unknown taskId: $taskId');
    }
    if (MCPTaskStatus.terminal.contains(task.status)) {
      return _errorResponse(request.id, -32602, 'Cannot cancel terminal task');
    }

    task.status = MCPTaskStatus.cancelled;
    task.statusMessage = 'Cancelled by client';
    task.lastUpdatedAt = DateTime.now().toUtc();
    _emitTaskStatus(task);
    if (!task.completer.isCompleted) {
      task.completer.complete();
    }

    return _successResponse(request.id, task.toPublicState().toJson());
  }

  bool _shouldEmitLog(String level) {
    final levels = MCPLoggingLevel.values;
    return levels.indexOf(level) >= levels.indexOf(_logLevel);
  }

  String _mapDartLogLevel(Level level) {
    if (level == Level.SHOUT) return MCPLoggingLevel.critical;
    if (level == Level.SEVERE) return MCPLoggingLevel.error;
    if (level == Level.WARNING) return MCPLoggingLevel.warning;
    if (level == Level.INFO) return MCPLoggingLevel.info;
    if (level == Level.CONFIG) return MCPLoggingLevel.notice;
    return MCPLoggingLevel.debug;
  }

  void _emitOutboundMessage(Map<String, dynamic> message) {
    _outboundMessagesController.add(message);
    _outboundMessageSink?.call(message);
  }

  Future<void> serve({
    int port = 8080,
    InternetAddress? address,
    bool enableCors = true,
    Duration keepAliveTimeout = const Duration(seconds: 30),
  }) async {
    address ??= InternetAddress.loopbackIPv4;

    _logger.info('Starting MCP Server on ${address.address}:$port');
    print('🔥 Starting MCP Server on ${address.address}:$port');

    try {
      final router = RelicApp()
        ..get('/health', _httpHandlers.healthCheckHandler)
        ..get('/status', _httpHandlers.statusHandler)
        ..use('/*', corsMiddleware(enableCors))
        ..use('/*', errorHandlingMiddleware(_logger))
        ..get('/ws', _httpHandlers.webSocketUpgradeHandler)
        ..get('/mcp', _httpHandlers.mcpSseHandler)
        ..get('/sse', _httpHandlers.mcpSseHandler)
        ..post('/mcp', _httpHandlers.mcpPostHandler)
        ..fallback = (request) => Response.notFound(
          body: Body.fromString('MCP Server - Endpoint not found'),
        );

      await router.serve(address: address, port: port);

      _logger.info('✓ MCP Server listening on ws://localhost:$port/ws');
      _logger.info('✓ Health check available at http://localhost:$port/health');

      ServerUtils.setupSignalHandlers(shutdown);
      _startConnectionMonitoring(keepAliveTimeout);
    } catch (e, stackTrace) {
      _logger.severe('Failed to start server: $e', e, stackTrace);
      rethrow;
    }
  }

  void _startConnectionMonitoring(Duration keepAliveTimeout) {
    _connectionMonitor = Timer.periodic(keepAliveTimeout, (timer) {
      _cleanupStaleConnections();
      _sessionManager.cleanupExpiredSessions();
    });
  }

  void _cleanupStaleConnections() {
    final staleConnections = _activeConnections
        .where((connection) => connection.isClosed)
        .toList();

    for (final connection in staleConnections) {
      _activeConnections.remove(connection);
    }

    if (staleConnections.isNotEmpty) {
      _logger.info('Cleaned up ${staleConnections.length} stale connections');
    }
  }

  Future<void> shutdown() async {
    _logger.info('Shutting down MCP Server...');

    _connectionMonitor?.cancel();
    await detachLogger();

    final futures = <Future>[];
    for (final connection in _activeConnections) {
      futures.add(connection.close());
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures, eagerError: false);
      _logger.info('Closed ${futures.length} WebSocket connections');
    }

    await _sessionManager.closeAllSessions();

    if (_server != null) {
      await _server!.close();
      _logger.info('Relic server closed');
    }

    await _outboundMessagesController.close();
    _logger.info('✓ MCP Server shutdown complete');
  }

  Future<void> stdio() => start();

  Future<void> start() async {
    _logger.info('Starting MCP server on stdio');
    setOutboundMessageSink((message) {
      print(jsonEncode(message));
    });

    final done = Completer<void>();
    late final StreamSubscription<String> subscription;
    subscription = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) async {
            try {
              final data = Map<String, dynamic>.from(jsonDecode(line) as Map);
              final response = await receiveMessage(data);
              if (response != null) {
                print(jsonEncode(response.toJson()));
              }
            } catch (e) {
              _logger.severe('Error processing stdin message: $e');
              final errorResponse = MCPResponse(
                error: MCPError(code: -32700, message: 'Parse error: $e'),
              );
              print(jsonEncode(errorResponse.toJson()));
            }
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!done.isCompleted) done.completeError(error, stackTrace);
          },
          cancelOnError: false,
        );

    await done.future;
    await subscription.cancel();
  }
}

class _ServerTask {
  final String taskId;
  final String toolName;
  final DateTime createdAt;
  DateTime lastUpdatedAt;
  final Duration ttl;
  final Duration pollInterval;
  final Map<String, Object?> arguments;
  final Map<String, String>? headers;
  final Completer<void> completer = Completer<void>();
  String status;
  String? statusMessage;
  Map<String, dynamic>? result;
  MCPError? error;

  _ServerTask({
    required this.taskId,
    required this.toolName,
    required this.status,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.ttl,
    required this.pollInterval,
    required this.arguments,
    this.headers,
  });

  MCPTaskState toPublicState() => MCPTaskState(
    taskId: taskId,
    status: status,
    createdAt: createdAt.toIso8601String(),
    lastUpdatedAt: lastUpdatedAt.toIso8601String(),
    statusMessage: statusMessage,
    ttl: ttl.inMilliseconds,
    pollInterval: pollInterval.inMilliseconds,
    metadata: {'toolName': toolName},
  );
}

extension on MCPTaskState {
  MCPTaskState copyWith({String? statusMessage}) => MCPTaskState(
    taskId: taskId,
    status: status,
    createdAt: createdAt,
    lastUpdatedAt: lastUpdatedAt,
    statusMessage: statusMessage ?? this.statusMessage,
    ttl: ttl,
    pollInterval: pollInterval,
    metadata: metadata,
  );
}
