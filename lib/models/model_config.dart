import '../logic/prompt_engine.dart';

class ModelConfig {
  final String id;          // Unique ID
  final String name;        // Display Name
  final String url;         // Download link
  final String filename;    // Local filename
  final ModelFormat format; // Prompt format

  const ModelConfig({
    required this.id,
    required this.name,
    required this.url,
    required this.filename,
    required this.format,
  });
}

class ModelRegistry {
  static const List<ModelConfig> models = [
    ModelConfig(
      id: 'qwen-2.5-1.5b',
      name: 'Qwen 2.5 (1.5B)',
      url: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      filename: 'qwen2.5-1.5b.gguf',
      format: ModelFormat.chatML,
    ),
    ModelConfig(
      id: 'tinyllama-1.1b',
      name: 'TinyLlama 1.1B',
      url: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
      filename: 'tinyllama-1.1b.gguf',
      format: ModelFormat.tinyLlama,
    ),
  ];

  static ModelConfig? findById(String id) {
    try {
      return models.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }
}