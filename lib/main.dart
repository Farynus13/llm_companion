import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'native_bridge.dart';
import 'models/chat_message.dart';
import 'logic/prompt_engine.dart';
import 'services/database_service.dart'; // Import Database

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
  // Services
  final NativeBridge _bridge = NativeBridge();
  final PromptEngine _promptEngine = PromptEngine();
  final DatabaseService _db = DatabaseService();
  final TextEditingController _controller = TextEditingController();

  // State
  int _currentConversationId = -1; // -1 means not initialized
  List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _sidebarChats = []; // List for the drawer
  
  String _status = "No model loaded.";
  bool _isModelLoaded = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadSidebar();
    // Don't create a new chat immediately, wait for user or create one on first message
  }

  // --- DATABASE LOGIC ---

  // Load the list of chats for the Drawer
  Future<void> _loadSidebar() async {
    final chats = await _db.getConversations();
    setState(() {
      _sidebarChats = chats;
    });
  }

  // Create a new blank chat
  Future<void> _startNewChat() async {
    // Generate a default title (e.g., "Chat #5")
    String title = "Chat #${_sidebarChats.length + 1}";
    int newId = await _db.createConversation(title);
    
    setState(() {
      _currentConversationId = newId;
      _messages = []; // Clear UI
    });
    
    await _loadSidebar(); // Refresh list
    Navigator.pop(context); // Close drawer if open
  }

  // Switch to an old chat
  Future<void> _loadChat(int id) async {
    final history = await _db.getMessages(id);
    setState(() {
      _currentConversationId = id;
      _messages = history;
    });
    Navigator.pop(context); // Close drawer
  }
  
  // ----------------------

  Future<void> _importAndLoadModel() async {
    // ... (Same import logic as before) ...
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Model',
        withReadStream: true, 
      );
      if (result == null) return; 

      setState(() => _status = "Importing...");
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
      });
    } catch (e) {
      setState(() => _status = "Error: $e");
    }
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty || !_isModelLoaded) return;
    String text = _controller.text;
    _controller.clear();

    // Auto-create chat if this is the first message
    if (_currentConversationId == -1) {
      // Use the first few words as the title
      String title = text.length > 20 ? "${text.substring(0, 20)}..." : text;
      _currentConversationId = await _db.createConversation(title);
      await _loadSidebar();
    }
    
    // 1. Create User Message
    final userMsg = ChatMessage(
      conversationId: _currentConversationId,
      content: text, 
      isUser: true, 
      timestamp: DateTime.now()
    );

    // 2. Save to DB & UI
    await _db.insertMessage(userMsg);
    setState(() {
      _messages.add(userMsg);
      _isBusy = true;
    });

    // 3. Generate Prompt
    String formattedPrompt = _promptEngine.buildPrompt(
      _messages.sublist(0, _messages.length - 1), 
      text 
    );

    // 4. Call C++
    await Future.delayed(const Duration(milliseconds: 50)); 
    String aiReply = _bridge.generate(formattedPrompt).trim();

    // 5. Create AI Message
    final aiMsg = ChatMessage(
      conversationId: _currentConversationId,
      content: aiReply, 
      isUser: false, 
      timestamp: DateTime.now()
    );

    // 6. Save to DB & UI
    await _db.insertMessage(aiMsg);
    setState(() {
      _messages.add(aiMsg);
      _isBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Local LLM Companion")),
      // --- THE SIDEBAR ---
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("My Conversations"),
              accountEmail: Text("${_sidebarChats.length} saved chats"),
              currentAccountPicture: const CircleAvatar(child: Icon(Icons.history)),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text("New Chat"),
              onTap: _startNewChat,
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _sidebarChats.length,
                itemBuilder: (context, index) {
                  final chat = _sidebarChats[index];
                  return ListTile(
                    title: Text(chat['title']),
                    selected: chat['id'] == _currentConversationId,
                    onTap: () => _loadChat(chat['id']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, size: 16, color: Colors.grey),
                      onPressed: () async {
                        await _db.deleteConversation(chat['id']);
                        _loadSidebar();
                        if (chat['id'] == _currentConversationId) {
                           setState(() => _messages = []); // Clear if deleted current
                        }
                      },
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
      // -------------------
      
      body: Column(
        children: [
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
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: _messages.isEmpty 
                ? const Center(child: Text("Start a new conversation!", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
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
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                          child: Text(msg.content),
                        ),
                      );
                    },
                  ),
            ),
          ),
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