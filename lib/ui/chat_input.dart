import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isBusy;
  final bool isModelLoaded;
  final VoidCallback onSend;

  const ChatInput({
    super.key,
    required this.controller,
    required this.isBusy,
    required this.isModelLoaded,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: isModelLoaded && !isBusy,
              minLines: 1,
              maxLines: 4, // Allow it to grow if typing long text
              decoration: const InputDecoration(
                hintText: "Type a message...",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onSubmitted: (_) => (isModelLoaded && !isBusy) ? onSend() : null,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            onPressed: (isModelLoaded && !isBusy) ? onSend : null,
            backgroundColor: isModelLoaded ? Colors.indigo : Colors.grey,
            child: isBusy 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}