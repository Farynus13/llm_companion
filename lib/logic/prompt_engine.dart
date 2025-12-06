import '../models/chat_message.dart';

// 1. Add 'tinyLlama' to the Enum
enum ModelFormat { chatML, alpaca, tinyLlama }

class PromptEngine {
  ModelFormat format;

  PromptEngine({this.format = ModelFormat.chatML});

  // 2. Define the Stop Token for the new format
  String get stopToken {
    if (format == ModelFormat.chatML) return "<|im_end|>";
    if (format == ModelFormat.tinyLlama) return "</s>"; // TinyLlama's stop word
    if (format == ModelFormat.alpaca) return "</s>"; 
    return "</s>";
  }

  String buildPrompt(List<ChatMessage> history, String newUserInput) {
    StringBuffer buffer = StringBuffer();

    // TinyLlama uses a specific System Tag
    if (format == ModelFormat.tinyLlama) {
       buffer.write("<|system|>\nYou are a helpful AI assistant.</s>\n");
    } else {
       buffer.write(_buildSystem("You are a helpful AI assistant."));
    }

    for (var msg in history) {
      if (msg.isUser) {
        buffer.write(_buildUser(msg.content));
      } else {
        buffer.write(_buildAssistant(msg.content));
      }
    }

    buffer.write(_buildUser(newUserInput));
    buffer.write(_startAssistant());

    return buffer.toString();
  }

  String _buildSystem(String content) {
    if (format == ModelFormat.chatML) return "<|im_start|>system\n$content<|im_end|>\n";
    // Alpaca typically skips system prompts or puts them in the first instruction
    return ""; 
  }

  String _buildUser(String content) {
    if (format == ModelFormat.chatML) return "<|im_start|>user\n$content<|im_end|>\n";
    if (format == ModelFormat.alpaca) return "### Instruction:\n$content\n\n";
    // 3. New TinyLlama Format
    if (format == ModelFormat.tinyLlama) return "<|user|>\n$content</s>\n";
    return content;
  }

  String _buildAssistant(String content) {
    if (format == ModelFormat.chatML) return "<|im_start|>assistant\n$content<|im_end|>\n";
    if (format == ModelFormat.alpaca) return "### Response:\n$content\n\n";
    // 3. New TinyLlama Format
    if (format == ModelFormat.tinyLlama) return "<|assistant|>\n$content</s>\n";
    return content;
  }
  
  String _startAssistant() {
    if (format == ModelFormat.chatML) return "<|im_start|>assistant\n";
    if (format == ModelFormat.alpaca) return "### Response:\n";
    // 3. New TinyLlama Format
    if (format == ModelFormat.tinyLlama) return "<|assistant|>\n";
    return "";
  }
}