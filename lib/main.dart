import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'native_bridge.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.blue),
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
  final TextEditingController _controller = TextEditingController();
  
  String _status = "Please select a model file (.gguf)";
  String _response = "";
  bool _isModelLoaded = false;
  bool _isLoading = false;

  // 1. Function to open File Picker
 Future<void> _pickModelFile() async {
    // REMOVED: The manual Permission.storage request which was causing the block.
    
    try {
      setState(() => _status = "Opening File Picker...");
      
      // Open the picker
      // allowCompression: false ensures it doesn't try to mess with the binary file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select your AI Model',
        allowCompression: false, 
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        setState(() => _status = "Loading: $path ...");
        
        // Slight delay to update UI
        await Future.delayed(const Duration(milliseconds: 100));

        // Load into C++
        bool success = await _bridge.loadModel(path);

        setState(() {
          _isModelLoaded = success;
          _status = success 
              ? "Model Loaded!\n(${path.split('/').last})" 
              : "Error: C++ failed to load model.";
        });
      } else {
        // User canceled
        setState(() => _status = "No file selected.");
      }
    } catch (e) {
      setState(() => _status = "Error: $e");
    }
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty || !_isModelLoaded) return;
    
    String userText = _controller.text;
    _controller.clear();
    
    setState(() {
      _response += "\n\nYou: $userText\nAI: Thinking...";
      _isLoading = true;
    });

    // This is the industry standard format for modern models.
    String formattedPrompt = 
      "<|im_start|>system\n"
      "You are a helpful and intelligent AI assistant.\n"
      "<|im_end|>\n"
      "<|im_start|>user\n"
      "$userText\n"
      "<|im_end|>\n"
      "<|im_start|>assistant\n";
    // -----------------------------------

    // Run inference (Short delay to allow UI to update "Thinking")
    await Future.delayed(const Duration(milliseconds: 50)); 
    
    // We send the FORMATTED prompt to C++, not the raw text
    String aiReply = _bridge.generate(formattedPrompt);

    setState(() {
      _response = _response.replaceFirst("Thinking...", aiReply.trim());
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Local LLM Companion")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // STATUS AREA
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isModelLoaded ? Colors.green[100] : Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(_status, style: const TextStyle(fontWeight: FontWeight.bold))),
                  if (!_isModelLoaded)
                    ElevatedButton(
                      onPressed: _pickModelFile,
                      child: const Text("Load Model"),
                    )
                ],
              ),
            ),
            const SizedBox(height: 10),
            
            // CHAT HISTORY
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(_response, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            
            // INPUT AREA
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller, 
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                    enabled: _isModelLoaded, // Disable input if no model
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()) 
                      : const Icon(Icons.send),
                  onPressed: (_isModelLoaded && !_isLoading) ? _sendMessage : null,
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}