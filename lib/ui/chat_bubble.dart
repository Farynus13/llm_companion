import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamic Colors
    final userBg = isDark ? Colors.indigo[900]! : Colors.indigo[100]!;
    final aiBg = isDark ? Colors.grey[800]! : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;
    
    // Code block background
    final codeBg = isDark ? Colors.black54 : Colors.grey[200];

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isUser ? userBg : aiBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: MarkdownBody(
          data: message.content,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black),
            // Code Block Styling
            code: TextStyle(
              backgroundColor: codeBg,
              fontFamily: 'monospace',
              fontSize: 14,
              color: isDark ? Colors.greenAccent : Colors.black87,
            ),
            codeblockDecoration: BoxDecoration(
              color: codeBg,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}