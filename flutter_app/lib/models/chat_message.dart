enum MessageRole { user, assistant }

class ChatMessage {
  const ChatMessage({required this.role, required this.content});
  final MessageRole role;
  final String content;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
        content: json['content'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'role': role == MessageRole.user ? 'user' : 'assistant',
        'content': content,
      };
}
