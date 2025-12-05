import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Import our new modules
import 'native_bridge.dart';
import 'models/chat_message.dart';
import 'logic/prompt_engine.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Companion',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final NativeBridge _bridge = NativeBridge();
  final PromptEngine _promptEngine = PromptEngine(); // The new logic handler
  final TextEditingController _controller = TextEditingController();
  
  // State
  final List<ChatMessage> _messages = []; // Structured History
  String _status = "No model loaded.";
  bool _isModelLoaded = false;
  bool _isBusy = false; 

  // --- IMPORT LOGIC (Kept here for now, can be moved to a Service later) ---
  Future<void> _importAndLoadModel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Model',
        withReadStream: true, 
      );

      if (result == null) return; 

      setState(() {
        _isBusy = true;
        _status = "Importing model...";
      });

      final directory = await getApplicationDocumentsDirectory();
      final String destPath = p.join(directory.path, "imported_model.gguf");

      PlatformFile pickedFile = result.files.single;
      if (pickedFile.path != null) {
        await File(pickedFile.path!).copy(destPath);
      } else if (pickedFile.readStream != null) {
        final sink = File(destPath).openWrite();
        await pickedFile.readStream!.pipe(sink);
        await sink.close();
      }

      setState(() => _status = "Loading Engine...");
      
      await Future.delayed(const Duration(milliseconds: 200));
      bool success = await _bridge.loadModel(destPath);

      setState(() {
        _isModelLoaded = success;
        _status = success ? "Ready: ${pickedFile.name}" : "Error Loading Engine";
        _isBusy = false;
      });

    } catch (e) {
      setState(() {
        _status = "Error: $e";
        _isBusy = false;
      });
    }
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty || !_isModelLoaded) return;
    String text = _controller.text;
    _controller.clear();
    
    // 1. Add User Message to UI
    setState(() {
      _messages.add(ChatMessage(
        content: text, 
        isUser: true, 
        timestamp: DateTime.now()
      ));
      _isBusy = true;
    });

    // 2. Build Prompt using the Logic Engine
    // We pass the history (minus the one we just added, or handle it inside)
    // Here we pass the NEW text separately as our engine expects.
    String formattedPrompt = _promptEngine.buildPrompt(
      _messages.sublist(0, _messages.length - 1), // History
      text // New Input
    );

    await Future.delayed(const Duration(milliseconds: 50)); 
    
    // 3. Call C++
    String aiReply = _bridge.generate(formattedPrompt);

    // 4. Add AI Message to UI
    setState(() {
      _messages.add(ChatMessage(
        content: aiReply.trim(), 
        isUser: false, 
        timestamp: DateTime.now()
      ));
      _isBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Local LLM Companion")),
      body: Column(
        children: [
          // Status Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: _isModelLoaded ? Colors.green[50] : Colors.blue[50],
            child: Row(
              children: [
                Expanded(child: Text(_status, style: const TextStyle(fontSize: 13))),
                if (!_isModelLoaded && !_isBusy)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.file_upload, size: 16),
                    label: const Text("Import Model"),
                    onPressed: _importAndLoadModel,
                  )
              ],
            ),
          ),
          
          // Chat List (The proper way to show chat)
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return Align(
                    alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: msg.isUser ? Colors.indigo[100] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      // Constraint width to 80% of screen
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                      child: Text(msg.content),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Input
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: _isModelLoaded && !_isBusy,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: (_isModelLoaded && !_isBusy) ? _sendMessage : null,
                  backgroundColor: _isModelLoaded ? Colors.indigo : Colors.grey,
                  child: _isBusy 
                    ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}