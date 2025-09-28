class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
  final List<String> fileIds;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? createdAt,
    List<String>? fileIds,
  })  : createdAt = createdAt ?? DateTime.now(),
        fileIds = fileIds ?? const [];

  bool get fromUser => role == 'user';
  bool get fromAssistant => role == 'assistant';
  bool get hasFileAttachments => fileIds.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      createdAt: _parseDate(json['createdAt']),
    fileIds: json['fileIds'] is List
      ? (json['fileIds'] as List)
        .where((element) => element != null)
        .map((element) => element.toString())
        .toList()
      : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'fileIds': fileIds,
      };
}

class ChatFile {
  final String id;
  final String fileName;
  final String? mimeType;
  final int size;
  final String downloadPath;
  final String? textPreview;
  final DateTime createdAt;

  ChatFile({
    required this.id,
    required this.fileName,
    this.mimeType,
    this.size = 0,
    required this.downloadPath,
    this.textPreview,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ChatFile.fromJson(Map<String, dynamic> json) {
    return ChatFile(
      id: json['id']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? 'file',
      mimeType: json['mimeType']?.toString(),
      size: json['size'] is int
          ? json['size'] as int
          : int.tryParse(json['size']?.toString() ?? '') ?? 0,
      downloadPath: json['downloadPath']?.toString() ?? '',
      textPreview: json['textPreview']?.toString(),
      createdAt: _parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'mimeType': mimeType,
        'size': size,
        'downloadPath': downloadPath,
        'textPreview': textPreview,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}

class Chat {
  final String id;
  final String uid;
  String? title;
  String? systemPrompt;
  DateTime createdAt;
  DateTime updatedAt;
  final List<ChatMessage> messages;
  final List<ChatFile> files;

  Chat({
    required this.id,
    required this.uid,
    this.title,
    this.systemPrompt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    List<ChatFile>? files,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [],
        files = files ?? [];

  factory Chat.fromJson(
    Map<String, dynamic> json, {
    List<ChatMessage>? messages,
    List<ChatFile>? files,
  }) {
    return Chat(
      id: json['id']?.toString() ?? '',
      uid: json['uid']?.toString() ?? '',
      title: json['title']?.toString(),
      systemPrompt: json['systemPrompt']?.toString(),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      messages: messages ??
          (json['messages'] is List
              ? (json['messages'] as List)
                  .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
                  .toList()
              : <ChatMessage>[]),
      files: files ??
          (json['files'] is List
              ? (json['files'] as List)
                  .whereType<Map<String, dynamic>>()
                  .map(ChatFile.fromJson)
                  .toList()
              : <ChatFile>[]),
    );
  }

  Map<String, dynamic> toJson({bool includeMessages = false}) {
    final data = <String, dynamic>{
      'id': id,
      'uid': uid,
      'title': title,
      'systemPrompt': systemPrompt,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'files': files.map((f) => f.toJson()).toList(),
    };
    if (includeMessages) {
      data['messages'] = messages.map((m) => m.toJson()).toList();
    }
    return data;
  }

  Chat copyWith({
    String? title,
    String? systemPrompt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    List<ChatFile>? files,
  }) {
    return Chat(
      id: id,
      uid: uid,
      title: title ?? this.title,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? List<ChatMessage>.from(this.messages),
      files: files ?? List<ChatFile>.from(this.files),
    );
  }
}

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      // ignore parsing error and fall through
    }
  }
  return DateTime.now();
}
