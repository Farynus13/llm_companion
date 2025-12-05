import '../models/chat_message.dart';

enum ModelFormat {
  chatML, // Qwen, generic
  alpaca, // Older models
  llama3, // New Llama
}

class PromptEngine {
  final ModelFormat format;

  PromptEngine({this.format = ModelFormat.chatML});

  /// Converts a list of message objects into the specific string format
  /// the AI engine expects.
  String buildPrompt(List<ChatMessage> history, String newUserInput) {
    StringBuffer buffer = StringBuffer();

    // 1. Add System Prompt (The "Personality")
    // We can make this configurable later
    buffer.write(_buildSystem("You are a helpful and intelligent AI assistant."));

    // 2. Add History
    for (var msg in history) {
      if (msg.isUser) {
        buffer.write(_buildUser(msg.content));
      } else {
        buffer.write(_buildAssistant(msg.content));
      }
    }

    // 3. Add the new input
    buffer.write(_buildUser(newUserInput));

    // 4. Prime the assistant to answer
    buffer.write(_startAssistant());

    return buffer.toString();
  }

  // --- Format Specifics (ChatML) ---
  // In the future, we can add 'switch(format)' here to support other models.

  String _buildSystem(String content) {
    return "<|im_start|>system\n$content<|im_end|>\n";
  }

  String _buildUser(String content) {
    return "<|im_start|>user\n$content<|im_end|>\n";
  }

  String _buildAssistant(String content) {
    return "<|im_start|>assistant\n$content<|im_end|>\n";
  }
  
  String _startAssistant() {
    return "<|im_start|>assistant\n";
  }
}