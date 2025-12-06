import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.indigo[100] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: MarkdownBody(
          data: message.content,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(fontSize: 16),
            code: TextStyle(
              backgroundColor: message.isUser ? Colors.indigo[200] : Colors.grey[200],
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            codeblockDecoration: BoxDecoration(
              color: message.isUser ? Colors.indigo[200] : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}