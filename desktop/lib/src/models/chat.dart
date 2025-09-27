class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get fromUser => role == 'user';
  bool get fromAssistant => role == 'assistant';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      createdAt: _parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
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

  Chat({
    required this.id,
    required this.uid,
    this.title,
    this.systemPrompt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [];

  factory Chat.fromJson(Map<String, dynamic> json, {List<ChatMessage>? messages}) {
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
  }) {
    return Chat(
      id: id,
      uid: uid,
      title: title ?? this.title,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? List<ChatMessage>.from(this.messages),
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
