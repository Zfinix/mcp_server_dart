/// MCP Protocol types and data structures
library;

/// Base class for all MCP requests.
class MCPRequest {
  final String jsonrpc;
  final String method;
  final Map<String, dynamic>? params;
  final Object? id;
  final Map<String, String>? headers;

  const MCPRequest({
    this.jsonrpc = '2.0',
    required this.method,
    this.params,
    this.id,
    this.headers,
  });

  factory MCPRequest.fromJson(Map<String, dynamic> json) => MCPRequest(
    jsonrpc: json['jsonrpc'] as String? ?? '2.0',
    method: json['method'] as String,
    params: json['params'] is Map
        ? Map<String, dynamic>.from(json['params'] as Map)
        : null,
    id: json['id'],
    headers: json['headers'] != null
        ? Map<String, String>.from(json['headers'] as Map)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'jsonrpc': jsonrpc,
    'method': method,
    if (params != null) 'params': params,
    if (id != null) 'id': id,
    if (headers != null) 'headers': headers,
  };

  MCPRequest withHeaders(Map<String, String> additionalHeaders) {
    if (additionalHeaders.isEmpty) return this;

    final mergedHeaders = <String, String>{};
    if (headers != null) {
      mergedHeaders.addAll(headers!);
    }
    mergedHeaders.addAll(additionalHeaders);

    return MCPRequest(
      jsonrpc: jsonrpc,
      method: method,
      params: params,
      id: id,
      headers: mergedHeaders,
    );
  }
}

/// Base class for all MCP responses.
class MCPResponse {
  final String jsonrpc;
  final dynamic result;
  final MCPError? error;
  final dynamic id;

  const MCPResponse({this.jsonrpc = '2.0', this.result, this.error, this.id});

  factory MCPResponse.fromJson(Map<String, dynamic> json) => MCPResponse(
    jsonrpc: json['jsonrpc'] as String? ?? '2.0',
    result: json['result'],
    error: json['error'] != null
        ? MCPError.fromJson(Map<String, dynamic>.from(json['error'] as Map))
        : null,
    id: json['id'],
  );

  Map<String, dynamic> toJson() => {
    'jsonrpc': jsonrpc,
    if (result != null) 'result': result,
    if (error != null) 'error': error!.toJson(),
    if (id != null) 'id': id,
  };
}

/// MCP Error structure.
class MCPError {
  final int code;
  final String message;
  final dynamic data;

  const MCPError({required this.code, required this.message, this.data});

  factory MCPError.fromJson(Map<String, dynamic> json) => MCPError(
    code: json['code'] as int,
    message: json['message'] as String,
    data: json['data'],
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    if (data != null) 'data': data,
  };
}

/// Icon metadata for tools/resources/prompts/server info.
class MCPIcon {
  final String src;
  final String? mimeType;
  final String? sizes;
  final String? theme;

  const MCPIcon({required this.src, this.mimeType, this.sizes, this.theme});

  factory MCPIcon.fromJson(Map<String, dynamic> json) => MCPIcon(
    src: json['src'] as String,
    mimeType: json['mimeType'] as String?,
    sizes: json['sizes'] as String?,
    theme: json['theme'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'src': src,
    if (mimeType != null) 'mimeType': mimeType,
    if (sizes != null) 'sizes': sizes,
    if (theme != null) 'theme': theme,
  };
}

/// Shared implementation info metadata used by initialize.
class MCPImplementationInfo {
  final String name;
  final String version;
  final String? title;
  final String? description;
  final String? websiteUrl;
  final List<MCPIcon>? icons;

  const MCPImplementationInfo({
    required this.name,
    required this.version,
    this.title,
    this.description,
    this.websiteUrl,
    this.icons,
  });

  factory MCPImplementationInfo.fromJson(Map<String, dynamic> json) =>
      MCPImplementationInfo(
        name: json['name'] as String,
        version: json['version'] as String,
        title: json['title'] as String?,
        description: json['description'] as String?,
        websiteUrl: json['websiteUrl'] as String?,
        icons: (json['icons'] as List<dynamic>?)
            ?.map(
              (icon) =>
                  MCPIcon.fromJson(Map<String, dynamic>.from(icon as Map)),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'version': version,
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    if (websiteUrl != null) 'websiteUrl': websiteUrl,
    if (icons != null) 'icons': icons!.map((icon) => icon.toJson()).toList(),
  };
}

/// Tool task support hints per MCP tasks spec.
class MCPTaskSupport {
  static const String forbidden = 'forbidden';
  static const String optional = 'optional';
  static const String required = 'required';
}

/// Tool annotations / metadata hints.
class MCPToolAnnotations {
  final bool? readOnlyHint;
  final bool? destructiveHint;
  final bool? idempotentHint;
  final bool? openWorldHint;
  final String? taskSupport;
  final String? title;

  const MCPToolAnnotations({
    this.readOnlyHint,
    this.destructiveHint,
    this.idempotentHint,
    this.openWorldHint,
    this.taskSupport,
    this.title,
  });

  factory MCPToolAnnotations.fromJson(Map<String, dynamic> json) =>
      MCPToolAnnotations(
        readOnlyHint: json['readOnlyHint'] as bool?,
        destructiveHint: json['destructiveHint'] as bool?,
        idempotentHint: json['idempotentHint'] as bool?,
        openWorldHint: json['openWorldHint'] as bool?,
        taskSupport: json['taskSupport'] as String?,
        title: json['title'] as String?,
      );

  Map<String, dynamic> toJson() => {
    if (readOnlyHint != null) 'readOnlyHint': readOnlyHint,
    if (destructiveHint != null) 'destructiveHint': destructiveHint,
    if (idempotentHint != null) 'idempotentHint': idempotentHint,
    if (openWorldHint != null) 'openWorldHint': openWorldHint,
    if (taskSupport != null) 'taskSupport': taskSupport,
    if (title != null) 'title': title,
  };
}

/// Tool definition.
class MCPToolDefinition {
  final String name;
  final String description;
  final String? title;
  final Map<String, dynamic>? inputSchema;
  final MCPToolAnnotations? annotations;
  final List<MCPIcon>? icons;

  const MCPToolDefinition({
    required this.name,
    required this.description,
    this.title,
    this.inputSchema,
    this.annotations,
    this.icons,
  });

  factory MCPToolDefinition.fromJson(Map<String, dynamic> json) =>
      MCPToolDefinition(
        name: json['name'] as String,
        description: json['description'] as String,
        title: json['title'] as String?,
        inputSchema: json['inputSchema'] is Map
            ? Map<String, dynamic>.from(json['inputSchema'] as Map)
            : null,
        annotations: json['annotations'] != null
            ? MCPToolAnnotations.fromJson(
                Map<String, dynamic>.from(json['annotations'] as Map),
              )
            : null,
        icons: (json['icons'] as List<dynamic>?)
            ?.map(
              (icon) =>
                  MCPIcon.fromJson(Map<String, dynamic>.from(icon as Map)),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() {
    final schema = inputSchema;
    final normalizedSchema = (schema == null || schema.isEmpty)
        ? {'type': 'object', 'properties': <String, dynamic>{}}
        : schema;

    return {
      'name': name,
      if (title != null) 'title': title,
      'description': description,
      'inputSchema': normalizedSchema,
      if (annotations != null) 'annotations': annotations!.toJson(),
      if (icons != null) 'icons': icons!.map((icon) => icon.toJson()).toList(),
    };
  }
}

/// Resource definition.
class MCPResourceDefinition {
  final String uri;
  final String name;
  final String description;
  final String? title;
  final String? mimeType;
  final List<MCPIcon>? icons;

  const MCPResourceDefinition({
    required this.uri,
    required this.name,
    required this.description,
    this.title,
    this.mimeType,
    this.icons,
  });

  factory MCPResourceDefinition.fromJson(Map<String, dynamic> json) =>
      MCPResourceDefinition(
        uri: json['uri'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        title: json['title'] as String?,
        mimeType: json['mimeType'] as String?,
        icons: (json['icons'] as List<dynamic>?)
            ?.map(
              (icon) =>
                  MCPIcon.fromJson(Map<String, dynamic>.from(icon as Map)),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'uri': uri,
    'name': name,
    if (title != null) 'title': title,
    'description': description,
    if (mimeType != null) 'mimeType': mimeType,
    if (icons != null) 'icons': icons!.map((icon) => icon.toJson()).toList(),
  };
}

/// Prompt definition.
class MCPPromptDefinition {
  final String name;
  final String description;
  final String? title;
  final List<MCPPromptArgument>? arguments;
  final List<MCPIcon>? icons;

  const MCPPromptDefinition({
    required this.name,
    required this.description,
    this.title,
    this.arguments,
    this.icons,
  });

  factory MCPPromptDefinition.fromJson(
    Map<String, dynamic> json,
  ) => MCPPromptDefinition(
    name: json['name'] as String,
    description: json['description'] as String,
    title: json['title'] as String?,
    arguments: (json['arguments'] as List<dynamic>?)
        ?.map(
          (arg) =>
              MCPPromptArgument.fromJson(Map<String, dynamic>.from(arg as Map)),
        )
        .toList(),
    icons: (json['icons'] as List<dynamic>?)
        ?.map(
          (icon) => MCPIcon.fromJson(Map<String, dynamic>.from(icon as Map)),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (title != null) 'title': title,
    'description': description,
    if (arguments != null)
      'arguments': arguments!.map((arg) => arg.toJson()).toList(),
    if (icons != null) 'icons': icons!.map((icon) => icon.toJson()).toList(),
  };
}

/// Prompt argument definition.
class MCPPromptArgument {
  final String name;
  final String description;
  final bool required;

  const MCPPromptArgument({
    required this.name,
    required this.description,
    this.required = false,
  });

  factory MCPPromptArgument.fromJson(Map<String, dynamic> json) =>
      MCPPromptArgument(
        name: json['name'] as String,
        description: json['description'] as String,
        required: json['required'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'required': required,
  };
}

/// Tool call context - provides access to parameters and metadata.
class MCPToolContext {
  final Map<String, dynamic> _params;
  final String toolName;
  final dynamic requestId;
  final Map<String, String>? _headers;

  MCPToolContext(
    this._params,
    this.toolName,
    this.requestId, {
    Map<String, String>? headers,
  }) : _headers = headers;

  /// Coerce a value to the expected type where possible.
  /// Currently handles bool ↔ String coercion so MCP clients that send
  /// "true"/"false" as strings work correctly.
  static dynamic _coerce(dynamic value, Type targetType) {
    if (value is String &&
        (targetType == bool || targetType.toString().contains('bool'))) {
      final lower = value.toLowerCase().trim();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return value;
  }

  T param<T>(String name, {T? defaultValue}) {
    final raw = _params[name];
    if (raw == null) {
      if (defaultValue != null) return defaultValue;
      throw ArgumentError('Required parameter "$name" is missing');
    }

    final value = _coerce(raw, T);
    if (value is! T) {
      throw ArgumentError(
        'Parameter "$name" expected type $T but got ${raw.runtimeType}',
      );
    }

    return value;
  }

  T? optionalParam<T>(String name) {
    final raw = _params[name];
    if (raw == null) return null;
    final value = _coerce(raw, T);
    return value is T ? value : null;
  }

  Map<String, dynamic> get allParams => Map.unmodifiable(_params);

  Map<String, String>? get headers =>
      _headers != null ? Map.unmodifiable(_headers) : null;

  String? header(String name) {
    if (_headers == null) return null;

    final lowerName = name.toLowerCase();
    final headerEntry = _headers.entries.firstWhere(
      (e) => e.key.toLowerCase() == lowerName,
      orElse: () => const MapEntry('', ''),
    );

    return headerEntry.key.isNotEmpty ? headerEntry.value : null;
  }
}

/// Resource content following MCP specification.
class MCPResourceContent {
  final String uri;
  final String name;
  final String? title;
  final String? description;
  final String? mimeType;
  final String? text;
  final String? blob;
  final int? size;
  final MCPResourceAnnotations? annotations;

  const MCPResourceContent({
    required this.uri,
    required this.name,
    this.title,
    this.description,
    this.mimeType,
    this.text,
    this.blob,
    this.size,
    this.annotations,
  });

  factory MCPResourceContent.fromJson(Map<String, dynamic> json) =>
      MCPResourceContent(
        uri: json['uri'] as String,
        name: json['name'] as String,
        title: json['title'] as String?,
        description: json['description'] as String?,
        mimeType: json['mimeType'] as String?,
        text: json['text'] as String?,
        blob: json['blob'] as String?,
        size: json['size'] as int?,
        annotations: json['annotations'] != null
            ? MCPResourceAnnotations.fromJson(
                Map<String, dynamic>.from(json['annotations'] as Map),
              )
            : null,
      );

  Map<String, dynamic> toJson() => {
    'uri': uri,
    'name': name,
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    if (mimeType != null) 'mimeType': mimeType,
    if (text != null) 'text': text,
    if (blob != null) 'blob': blob,
    if (size != null) 'size': size,
    if (annotations != null) 'annotations': annotations!.toJson(),
  };
}

/// Resource metadata hints.
class MCPResourceAnnotations {
  final List<String>? audience;
  final double? priority;
  final String? lastModified;

  const MCPResourceAnnotations({
    this.audience,
    this.priority,
    this.lastModified,
  });

  factory MCPResourceAnnotations.fromJson(Map<String, dynamic> json) =>
      MCPResourceAnnotations(
        audience: (json['audience'] as List<dynamic>?)?.cast<String>(),
        priority: (json['priority'] as num?)?.toDouble(),
        lastModified: json['lastModified'] as String?,
      );

  Map<String, dynamic> toJson() => {
    if (audience != null) 'audience': audience,
    if (priority != null) 'priority': priority,
    if (lastModified != null) 'lastModified': lastModified,
  };
}

/// Resource link returned from a tool result.
class MCPResourceLink {
  final String uri;
  final String name;
  final String? title;
  final String? description;
  final String? mimeType;

  const MCPResourceLink({
    required this.uri,
    required this.name,
    this.title,
    this.description,
    this.mimeType,
  });

  factory MCPResourceLink.fromJson(Map<String, dynamic> json) =>
      MCPResourceLink(
        uri: json['uri'] as String,
        name: json['name'] as String,
        title: json['title'] as String?,
        description: json['description'] as String?,
        mimeType: json['mimeType'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'uri': uri,
    'name': name,
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    if (mimeType != null) 'mimeType': mimeType,
  };
}

/// Tool result.
class MCPToolResult {
  final dynamic content;
  final bool isError;
  final Object? structuredContent;
  final List<MCPResourceLink>? resourceLinks;

  const MCPToolResult({
    required this.content,
    this.isError = false,
    this.structuredContent,
    this.resourceLinks,
  });

  factory MCPToolResult.fromJson(Map<String, dynamic> json) => MCPToolResult(
    content: json['content'],
    isError: json['isError'] as bool? ?? false,
    structuredContent: json['structuredContent'],
    resourceLinks: (json['resourceLinks'] as List<dynamic>?)
        ?.map(
          (link) =>
              MCPResourceLink.fromJson(Map<String, dynamic>.from(link as Map)),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'content': content,
    'isError': isError,
    if (structuredContent != null) 'structuredContent': structuredContent,
    if (resourceLinks != null)
      'resourceLinks': resourceLinks!.map((link) => link.toJson()).toList(),
  };
}

// =============================================================================
// MCP CONTENT TYPES
// =============================================================================

abstract class MCPContent {
  const MCPContent();

  Map<String, dynamic> toJson();
}

class TextContent extends MCPContent {
  final String text;

  const TextContent(this.text);

  @override
  Map<String, dynamic> toJson() => {'type': 'text', 'text': text};
}

class ImageContent extends MCPContent {
  final String data;
  final String mimeType;

  const ImageContent({required this.data, this.mimeType = 'image/png'});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'image',
    'data': data,
    'mimeType': mimeType,
  };
}

class ResourceContent extends MCPContent {
  final MCPResourceContent resource;

  const ResourceContent(this.resource);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'resource',
    'resource': resource.toJson(),
  };
}

// =============================================================================
// MODERN CAPABILITIES / INITIALIZE TYPES
// =============================================================================

class MCPListChangedCapability {
  final bool? listChanged;

  const MCPListChangedCapability({this.listChanged});

  factory MCPListChangedCapability.fromJson(Map<String, dynamic> json) =>
      MCPListChangedCapability(listChanged: json['listChanged'] as bool?);

  Map<String, dynamic> toJson() => {
    if (listChanged != null) 'listChanged': listChanged,
  };
}

class MCPResourceCapabilities {
  final bool? subscribe;
  final bool? listChanged;

  const MCPResourceCapabilities({this.subscribe, this.listChanged});

  factory MCPResourceCapabilities.fromJson(Map<String, dynamic> json) =>
      MCPResourceCapabilities(
        subscribe: json['subscribe'] as bool?,
        listChanged: json['listChanged'] as bool?,
      );

  Map<String, dynamic> toJson() => {
    if (subscribe != null) 'subscribe': subscribe,
    if (listChanged != null) 'listChanged': listChanged,
  };
}

class MCPTasksCapability {
  final bool list;
  final bool cancel;
  final bool toolsCall;
  final bool samplingCreateMessage;
  final bool elicitationCreate;

  const MCPTasksCapability({
    this.list = false,
    this.cancel = false,
    this.toolsCall = false,
    this.samplingCreateMessage = false,
    this.elicitationCreate = false,
  });

  factory MCPTasksCapability.fromJson(Map<String, dynamic> json) {
    final requests = json['requests'] is Map
        ? Map<String, dynamic>.from(json['requests'] as Map)
        : const <String, dynamic>{};
    final tools = requests['tools'] is Map
        ? Map<String, dynamic>.from(requests['tools'] as Map)
        : const <String, dynamic>{};
    final sampling = requests['sampling'] is Map
        ? Map<String, dynamic>.from(requests['sampling'] as Map)
        : const <String, dynamic>{};
    final elicitation = requests['elicitation'] is Map
        ? Map<String, dynamic>.from(requests['elicitation'] as Map)
        : const <String, dynamic>{};
    return MCPTasksCapability(
      list: json.containsKey('list'),
      cancel: json.containsKey('cancel'),
      toolsCall: tools.containsKey('call'),
      samplingCreateMessage: sampling.containsKey('createMessage'),
      elicitationCreate: elicitation.containsKey('create'),
    );
  }

  Map<String, dynamic> toServerJson() {
    final requests = <String, dynamic>{};
    if (toolsCall) {
      requests['tools'] = {'call': {}};
    }
    if (requests.isEmpty && !list && !cancel) {
      return {};
    }
    return {
      if (list) 'list': {},
      if (cancel) 'cancel': {},
      if (requests.isNotEmpty) 'requests': requests,
    };
  }

  Map<String, dynamic> toClientJson() {
    final requests = <String, dynamic>{};
    if (samplingCreateMessage) {
      requests['sampling'] = {'createMessage': {}};
    }
    if (elicitationCreate) {
      requests['elicitation'] = {'create': {}};
    }
    if (requests.isEmpty && !list && !cancel) {
      return {};
    }
    return {
      if (list) 'list': {},
      if (cancel) 'cancel': {},
      if (requests.isNotEmpty) 'requests': requests,
    };
  }
}

class MCPServerCapabilities {
  final MCPListChangedCapability? prompts;
  final MCPResourceCapabilities? resources;
  final MCPListChangedCapability? tools;
  final bool logging;
  final bool completions;
  final MCPTasksCapability? tasks;
  final Map<String, dynamic>? experimental;

  const MCPServerCapabilities({
    this.prompts,
    this.resources,
    this.tools,
    this.logging = false,
    this.completions = false,
    this.tasks,
    this.experimental,
  });

  factory MCPServerCapabilities.fromJson(Map<String, dynamic> json) =>
      MCPServerCapabilities(
        prompts: json['prompts'] != null
            ? MCPListChangedCapability.fromJson(
                Map<String, dynamic>.from(json['prompts'] as Map),
              )
            : null,
        resources: json['resources'] != null
            ? MCPResourceCapabilities.fromJson(
                Map<String, dynamic>.from(json['resources'] as Map),
              )
            : null,
        tools: json['tools'] != null
            ? MCPListChangedCapability.fromJson(
                Map<String, dynamic>.from(json['tools'] as Map),
              )
            : null,
        logging: json.containsKey('logging'),
        completions: json.containsKey('completions'),
        tasks: json['tasks'] != null
            ? MCPTasksCapability.fromJson(
                Map<String, dynamic>.from(json['tasks'] as Map),
              )
            : null,
        experimental: json['experimental'] is Map
            ? Map<String, dynamic>.from(json['experimental'] as Map)
            : null,
      );

  Map<String, dynamic> toJson() => {
    if (logging) 'logging': {},
    if (completions) 'completions': {},
    if (prompts != null) 'prompts': prompts!.toJson(),
    if (resources != null) 'resources': resources!.toJson(),
    if (tools != null) 'tools': tools!.toJson(),
    if (tasks != null && tasks!.toServerJson().isNotEmpty)
      'tasks': tasks!.toServerJson(),
    if (experimental != null && experimental!.isNotEmpty)
      'experimental': experimental,
  };
}

class MCPClientCapabilities {
  final bool roots;
  final bool rootsListChanged;
  final bool sampling;
  final bool samplingContext;
  final bool samplingTools;
  final bool elicitation;
  final bool elicitationForm;
  final bool elicitationUrl;
  final MCPTasksCapability? tasks;
  final Map<String, dynamic>? experimental;

  const MCPClientCapabilities({
    this.roots = false,
    this.rootsListChanged = false,
    this.sampling = false,
    this.samplingContext = false,
    this.samplingTools = false,
    this.elicitation = false,
    this.elicitationForm = false,
    this.elicitationUrl = false,
    this.tasks,
    this.experimental,
  });

  factory MCPClientCapabilities.fromJson(Map<String, dynamic> json) {
    final roots = json['roots'] is Map
        ? Map<String, dynamic>.from(json['roots'] as Map)
        : const <String, dynamic>{};
    final sampling = json['sampling'] is Map
        ? Map<String, dynamic>.from(json['sampling'] as Map)
        : const <String, dynamic>{};
    final elicitation = json['elicitation'] is Map
        ? Map<String, dynamic>.from(json['elicitation'] as Map)
        : const <String, dynamic>{};
    return MCPClientCapabilities(
      roots: json.containsKey('roots'),
      rootsListChanged: roots['listChanged'] as bool? ?? false,
      sampling: json.containsKey('sampling'),
      samplingContext: sampling.containsKey('context'),
      samplingTools: sampling.containsKey('tools'),
      elicitation: json.containsKey('elicitation'),
      elicitationForm: elicitation.containsKey('form'),
      elicitationUrl: elicitation.containsKey('url'),
      tasks: json['tasks'] != null
          ? MCPTasksCapability.fromJson(
              Map<String, dynamic>.from(json['tasks'] as Map),
            )
          : null,
      experimental: json['experimental'] is Map
          ? Map<String, dynamic>.from(json['experimental'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (roots) 'roots': {if (rootsListChanged) 'listChanged': rootsListChanged},
    if (sampling)
      'sampling': {
        if (samplingContext) 'context': {},
        if (samplingTools) 'tools': {},
      },
    if (elicitation)
      'elicitation': {
        if (elicitationForm) 'form': {},
        if (elicitationUrl) 'url': {},
      },
    if (tasks != null && tasks!.toClientJson().isNotEmpty)
      'tasks': tasks!.toClientJson(),
    if (experimental != null && experimental!.isNotEmpty)
      'experimental': experimental,
  };
}

class MCPInitializeResult {
  final String protocolVersion;
  final MCPServerCapabilities capabilities;
  final MCPImplementationInfo serverInfo;
  final String? instructions;

  const MCPInitializeResult({
    required this.protocolVersion,
    required this.capabilities,
    required this.serverInfo,
    this.instructions,
  });

  factory MCPInitializeResult.fromJson(Map<String, dynamic> json) =>
      MCPInitializeResult(
        protocolVersion: json['protocolVersion'] as String,
        capabilities: MCPServerCapabilities.fromJson(
          Map<String, dynamic>.from(json['capabilities'] as Map),
        ),
        serverInfo: MCPImplementationInfo.fromJson(
          Map<String, dynamic>.from(json['serverInfo'] as Map),
        ),
        instructions: json['instructions'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'protocolVersion': protocolVersion,
    'capabilities': capabilities.toJson(),
    'serverInfo': serverInfo.toJson(),
    if (instructions != null) 'instructions': instructions,
  };
}

// =============================================================================
// LOGGING TYPES
// =============================================================================

class MCPLoggingLevel {
  static const debug = 'debug';
  static const info = 'info';
  static const notice = 'notice';
  static const warning = 'warning';
  static const error = 'error';
  static const critical = 'critical';
  static const alert = 'alert';
  static const emergency = 'emergency';

  static const values = <String>[
    debug,
    info,
    notice,
    warning,
    error,
    critical,
    alert,
    emergency,
  ];

  static bool isValid(String level) => values.contains(level);
}

class MCPLogMessageNotification {
  final String level;
  final String? logger;
  final Object? data;

  const MCPLogMessageNotification({
    required this.level,
    this.logger,
    this.data,
  });

  Map<String, dynamic> toJson() => {
    'jsonrpc': '2.0',
    'method': 'notifications/message',
    'params': {
      'level': level,
      if (logger != null) 'logger': logger,
      'data': data,
    },
  };
}

// =============================================================================
// COMPLETION TYPES
// =============================================================================

class MCPCompletionReference {
  final String type;
  final String? name;
  final String? uri;
  final String? title;

  const MCPCompletionReference({
    required this.type,
    this.name,
    this.uri,
    this.title,
  });

  factory MCPCompletionReference.prompt(String name, {String? title}) =>
      MCPCompletionReference(type: 'ref/prompt', name: name, title: title);

  factory MCPCompletionReference.resource(String uri) =>
      MCPCompletionReference(type: 'ref/resource', uri: uri);

  factory MCPCompletionReference.fromJson(Map<String, dynamic> json) =>
      MCPCompletionReference(
        type: json['type'] as String,
        name: json['name'] as String?,
        uri: json['uri'] as String?,
        title: json['title'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'type': type,
    if (name != null) 'name': name,
    if (uri != null) 'uri': uri,
    if (title != null) 'title': title,
  };
}

class MCPCompletionArgument {
  final String name;
  final String value;

  const MCPCompletionArgument({required this.name, required this.value});

  factory MCPCompletionArgument.fromJson(Map<String, dynamic> json) =>
      MCPCompletionArgument(
        name: json['name'] as String,
        value: json['value'] as String,
      );

  Map<String, dynamic> toJson() => {'name': name, 'value': value};
}

class MCPCompletionContext {
  final Map<String, String> arguments;

  const MCPCompletionContext({this.arguments = const {}});

  factory MCPCompletionContext.fromJson(Map<String, dynamic> json) =>
      MCPCompletionContext(
        arguments: json['arguments'] is Map
            ? Map<String, String>.from(json['arguments'] as Map)
            : const {},
      );

  Map<String, dynamic> toJson() => {
    if (arguments.isNotEmpty) 'arguments': arguments,
  };
}

class MCPCompletionRequest {
  final MCPCompletionReference ref;
  final MCPCompletionArgument argument;
  final MCPCompletionContext? context;

  const MCPCompletionRequest({
    required this.ref,
    required this.argument,
    this.context,
  });

  factory MCPCompletionRequest.fromJson(Map<String, dynamic> json) =>
      MCPCompletionRequest(
        ref: MCPCompletionReference.fromJson(
          Map<String, dynamic>.from(json['ref'] as Map),
        ),
        argument: MCPCompletionArgument.fromJson(
          Map<String, dynamic>.from(json['argument'] as Map),
        ),
        context: json['context'] != null
            ? MCPCompletionContext.fromJson(
                Map<String, dynamic>.from(json['context'] as Map),
              )
            : null,
      );

  Map<String, dynamic> toJson() => {
    'ref': ref.toJson(),
    'argument': argument.toJson(),
    if (context != null) 'context': context!.toJson(),
  };
}

class MCPCompletionData {
  final List<String> values;
  final int? total;
  final bool? hasMore;

  const MCPCompletionData({required this.values, this.total, this.hasMore});

  factory MCPCompletionData.fromJson(Map<String, dynamic> json) =>
      MCPCompletionData(
        values: (json['values'] as List<dynamic>).cast<String>(),
        total: json['total'] as int?,
        hasMore: json['hasMore'] as bool?,
      );

  Map<String, dynamic> toJson() => {
    'values': values,
    if (total != null) 'total': total,
    if (hasMore != null) 'hasMore': hasMore,
  };
}

class MCPCompletionResult {
  final MCPCompletionData completion;

  const MCPCompletionResult({required this.completion});

  factory MCPCompletionResult.fromJson(Map<String, dynamic> json) =>
      MCPCompletionResult(
        completion: MCPCompletionData.fromJson(
          Map<String, dynamic>.from(json['completion'] as Map),
        ),
      );

  Map<String, dynamic> toJson() => {'completion': completion.toJson()};
}

// =============================================================================
// TASK TYPES
// =============================================================================

class MCPTaskMetadata {
  final Duration? ttl;

  const MCPTaskMetadata({this.ttl});

  factory MCPTaskMetadata.fromJson(Map<String, dynamic> json) =>
      MCPTaskMetadata(
        ttl: json['ttl'] is int
            ? Duration(milliseconds: json['ttl'] as int)
            : null,
      );

  Map<String, dynamic> toJson() => {
    if (ttl != null) 'ttl': ttl!.inMilliseconds,
  };
}

class MCPTaskStatus {
  static const working = 'working';
  static const inputRequired = 'input_required';
  static const completed = 'completed';
  static const failed = 'failed';
  static const cancelled = 'cancelled';

  static const terminal = <String>{completed, failed, cancelled};
}

class MCPTaskState {
  final String taskId;
  final String status;
  final String createdAt;
  final String lastUpdatedAt;
  final String? statusMessage;
  final int? ttl;
  final int? pollInterval;
  final Map<String, dynamic>? metadata;

  const MCPTaskState({
    required this.taskId,
    required this.status,
    required this.createdAt,
    required this.lastUpdatedAt,
    this.statusMessage,
    this.ttl,
    this.pollInterval,
    this.metadata,
  });

  factory MCPTaskState.fromJson(Map<String, dynamic> json) => MCPTaskState(
    taskId: json['taskId'] as String,
    status: json['status'] as String,
    createdAt: json['createdAt'] as String,
    lastUpdatedAt: json['lastUpdatedAt'] as String,
    statusMessage: json['statusMessage'] as String?,
    ttl: json['ttl'] as int?,
    pollInterval: json['pollInterval'] as int?,
    metadata: json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'status': status,
    'createdAt': createdAt,
    'lastUpdatedAt': lastUpdatedAt,
    if (statusMessage != null) 'statusMessage': statusMessage,
    if (ttl != null) 'ttl': ttl,
    if (pollInterval != null) 'pollInterval': pollInterval,
    if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
    '_meta': {'io.modelcontextprotocol/related-task': taskId},
  };
}

class MCPCreateTaskResult {
  final MCPTaskState task;
  final Map<String, dynamic>? immediateResponseMeta;

  const MCPCreateTaskResult({this.immediateResponseMeta, required this.task});

  Map<String, dynamic> toJson() => {
    'task': task.toJson(),
    if (immediateResponseMeta != null && immediateResponseMeta!.isNotEmpty)
      '_meta': immediateResponseMeta,
  };
}

class MCPTaskListResult {
  final List<MCPTaskState> tasks;
  final String? nextCursor;

  const MCPTaskListResult({required this.tasks, this.nextCursor});

  Map<String, dynamic> toJson() => {
    'tasks': tasks.map((task) => task.toJson()).toList(),
    if (nextCursor != null) 'nextCursor': nextCursor,
  };
}

class MCPTaskStatusNotification {
  final String taskId;
  final String status;
  final String? statusMessage;

  const MCPTaskStatusNotification({
    required this.taskId,
    required this.status,
    this.statusMessage,
  });

  Map<String, dynamic> toJson() => {
    'jsonrpc': '2.0',
    'method': 'notifications/tasks/status',
    'params': {
      'taskId': taskId,
      'status': status,
      if (statusMessage != null) 'statusMessage': statusMessage,
    },
  };
}

// =============================================================================
// CLIENT-INTERACTION TYPES
// =============================================================================

class MCPRootInfo {
  final String uri;
  final String? name;

  const MCPRootInfo({required this.uri, this.name});

  factory MCPRootInfo.fromJson(Map<String, dynamic> json) =>
      MCPRootInfo(uri: json['uri'] as String, name: json['name'] as String?);

  Map<String, dynamic> toJson() => {'uri': uri, if (name != null) 'name': name};
}

class MCPRootsListResult {
  final List<MCPRootInfo> roots;

  const MCPRootsListResult({required this.roots});

  factory MCPRootsListResult.fromJson(Map<String, dynamic> json) =>
      MCPRootsListResult(
        roots: (json['roots'] as List<dynamic>)
            .map(
              (root) =>
                  MCPRootInfo.fromJson(Map<String, dynamic>.from(root as Map)),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'roots': roots.map((root) => root.toJson()).toList(),
  };
}

class MCPSamplingRequest {
  final Map<String, dynamic> payload;

  const MCPSamplingRequest(this.payload);

  Map<String, dynamic> toJson() => payload;
}

class MCPElicitationRequest {
  final Map<String, dynamic> payload;

  const MCPElicitationRequest(this.payload);

  factory MCPElicitationRequest.form({
    required String message,
    required Map<String, dynamic> requestedSchema,
  }) => MCPElicitationRequest({
    'mode': 'form',
    'message': message,
    'requestedSchema': requestedSchema,
  });

  factory MCPElicitationRequest.url({
    required String message,
    required String elicitationId,
    required String url,
  }) => MCPElicitationRequest({
    'mode': 'url',
    'message': message,
    'elicitationId': elicitationId,
    'url': url,
  });

  Map<String, dynamic> toJson() => payload;
}
