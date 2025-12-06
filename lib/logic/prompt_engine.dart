import '../models/chat_message.dart';

enum ModelFormat { chatML, alpaca, tinyLlama }

class PromptEngine {
  ModelFormat format;

  // SAFE LIMIT: ~4000 chars to prevent crashes
  static const int _maxPromptChars = 4000; 

  PromptEngine({this.format = ModelFormat.chatML});

  String get stopToken {
    if (format == ModelFormat.chatML) return "<|im_end|>";
    if (format == ModelFormat.tinyLlama) return "</s>";
    if (format == ModelFormat.alpaca) return "</s>";
    return "</s>";
  }

  String buildPrompt(List<ChatMessage> history, String newUserInput) {
    // 1. Prepare Mandatory Parts
    String systemStr = _buildSystem("You are a helpful AI assistant.");
    String userInputStr = _buildUser(newUserInput);
    String assistantStartStr = _startAssistant();

    // 2. Calculate remaining budget
    int currentLength = systemStr.length + userInputStr.length + assistantStartStr.length;
    int budget = _maxPromptChars - currentLength;

    // 3. Select History (Backwards)
    List<String> selectedHistory = [];
    
    for (int i = history.length - 1; i >= 0; i--) {
      ChatMessage msg = history[i];
      String msgStr = msg.isUser 
          ? _buildUser(msg.content) 
          : _buildAssistant(msg.content);

      if (budget - msgStr.length < 0) {
        break; // Stop if full
      }

      selectedHistory.add(msgStr);
      budget -= msgStr.length;
    }

    // 4. Construct Final Prompt
    StringBuffer buffer = StringBuffer();
    
    buffer.write(systemStr);
    
    // Reverse back to Chronological order
    for (var msgStr in selectedHistory.reversed) {
      buffer.write(msgStr);
    }

    buffer.write(userInputStr);
    buffer.write(assistantStartStr);

    return buffer.toString();
  }

  // --- Formatters ---
  
  String _buildSystem(String content) {
    if (format == ModelFormat.chatML) return "<|im_start|>system\n$content<|im_end|>\n";
    if (format == ModelFormat.tinyLlama) return "<|system|>\n$content</s>\n";
    return ""; 
  }

  String _buildUser(String content) {
    if (format == ModelFormat.chatML) return "<|im_start|>user\n$content<|im_end|>\n";
    if (format == ModelFormat.alpaca) return "### Instruction:\n$content\n\n";
    if (format == ModelFormat.tinyLlama) return "<|user|>\n$content</s>\n";
    return content;
  }

  String _buildAssistant(String content) {
    if (format == ModelFormat.chatML) return "<|im_start|>assistant\n$content<|im_end|>\n";
    if (format == ModelFormat.alpaca) return "### Response:\n$content\n\n";
    if (format == ModelFormat.tinyLlama) return "<|assistant|>\n$content</s>\n";
    return content;
  }
  
  String _startAssistant() {
    if (format == ModelFormat.chatML) return "<|im_start|>assistant\n";
    if (format == ModelFormat.alpaca) return "### Response:\n";
    if (format == ModelFormat.tinyLlama) return "<|assistant|>\n";
    return "";
  }
}