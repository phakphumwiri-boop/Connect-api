import 'package:flutter_test/flutter_test.dart';
import 'package:ish_app/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('decodes user message', () {
      final message = ChatMessage.fromJson({'role': 'user', 'content': 'Hello'});
      expect(message.role, MessageRole.user);
      expect(message.content, 'Hello');
    });
    test('unknown roles default to assistant and round-trip', () {
      final message = ChatMessage.fromJson({'role': 'system', 'content': 'Ready'});
      expect(message.role, MessageRole.assistant);
      expect(message.toJson(), {'role': 'assistant', 'content': 'Ready'});
    });
  });
}
