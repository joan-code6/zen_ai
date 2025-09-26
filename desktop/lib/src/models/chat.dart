class ChatMessage {
  final String id;
  final String text;
  final bool fromUser;
  final DateTime time;

  ChatMessage({required this.id, required this.text, required this.fromUser, DateTime? time}) : time = time ?? DateTime.now();
}

class Chat {
  final String id;
  String title;
  final List<ChatMessage> messages;

  Chat({required this.id, required this.title, List<ChatMessage>? messages}) : messages = messages ?? [];
}
