/// One turn in the AI Correction Assistant chat (popup quiz side panel).
class ChatMessage {
  ChatMessage({required this.isUser, required this.text, this.caption})
      : time = DateTime.now();

  final bool isUser;
  final String text;
  final String? caption;
  final DateTime time;
}
