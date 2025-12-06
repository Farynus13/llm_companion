import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'native_bridge.dart';
import 'models/chat_message.dart';
import 'models/model_config.dart';
import 'logic/prompt_engine.dart';
import 'services/database_service.dart';
import 'ui/model_sheet.dart';

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
  final PromptEngine _promptEngine = PromptEngine();
  final DatabaseService _db = DatabaseService();
  final TextEditingController _controller = TextEditingController();

  int _currentConversationId = -1;
  List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _sidebarChats = [];
  
  String _status = "Initializing...";
  bool _isModelLoaded = false;
  bool _isBusy = false;
  String _loadedModelName = "None";

  @override
  void initState() {
    super.initState();
    _loadSidebar();
    _autoLoadLastModel();
  }

  // 1. Auto Load Logic
  Future<void> _autoLoadLastModel() async {
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString('last_model_id');
    
    if (lastId != null) {
      final config = ModelRegistry.findById(lastId);
      if (config != null) {
        // Check if file exists
        final dir = await getApplicationDocumentsDirectory();
        final path = p.join(dir.path, config.filename);
        
        if (await File(path).exists()) {
          _loadModelInternal(path, config);
        } else {
          setState(() => _status = "Last model found but file missing. Please download again.");
        }
      }
    } else {
      setState(() => _status = "Select a model to begin.");
    }
  }

  // 2. Shared Loading Function
  Future<void> _loadModelInternal(String path, ModelConfig config) async {
    setState(() {
      _status = "Loading ${config.name}...";
      _isBusy = true;
    });
    
    // Update Prompt Engine Format automatically!
    _promptEngine.format = config.format;

    await Future.delayed(const Duration(milliseconds: 200));
    bool success = await _bridge.loadModel(path);

    setState(() {
      _isModelLoaded = success;
      _loadedModelName = config.name;
      _status = success ? "Ready" : "Failed to load";
      _isBusy = false;
    });
  }

  // 3. Show the Model Selection Sheet
  void _openModelManager() {
    showModalBottomSheet(
      context: context, 
      builder: (context) => ModelSheet(
        onModelSelected: (path, config) => _loadModelInternal(path, config),
      )
    );
  }

  Future<void> _loadSidebar() async {
    final chats = await _db.getConversations();
    setState(() => _sidebarChats = chats);
  }

  Future<void> _startNewChat() async {
    String title = "Chat #${_sidebarChats.length + 1}";
    int newId = await _db.createConversation(title);
    setState(() {
      _currentConversationId = newId;
      _messages = [];
    });
    await _loadSidebar();
    Navigator.pop(context);
  }

  Future<void> _loadChat(int id) async {
    final history = await _db.getMessages(id);
    setState(() {
      _currentConversationId = id;
      _messages = history;
    });
    Navigator.pop(context);
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty || !_isModelLoaded) return;
    String text = _controller.text;
    _controller.clear();

    if (_currentConversationId == -1) {
      String title = text.length > 20 ? "${text.substring(0, 20)}..." : text;
      _currentConversationId = await _db.createConversation(title);
      await _loadSidebar();
    }
    
    // 1. User Message
    final userMsg = ChatMessage(
        conversationId: _currentConversationId, content: text, isUser: true, timestamp: DateTime.now());
    await _db.insertMessage(userMsg);
    
    // 2. Prepare Placeholder for AI Message
    // We create an empty AI message instantly so we can "fill it up" as tokens arrive
    final aiMsg = ChatMessage(
        conversationId: _currentConversationId, content: "", isUser: false, timestamp: DateTime.now());
    
    setState(() {
      _messages.add(userMsg);
      _messages.add(aiMsg); // Add empty AI bubble
      _isBusy = true;
    });

    // 3. Build Prompt
    String formattedPrompt = _promptEngine.buildPrompt(
      _messages.sublist(0, _messages.length - 2), // Exclude the 2 new messages from history context
      text 
    );

    // 4. STREAMING LOGIC
    String fullResponse = "";
    
    // Listen to the stream
    _bridge.generateStream(formattedPrompt, _promptEngine.stopToken).listen(
      (token) {
        fullResponse += token;
        
        // Update the UI instantly
        setState(() {
          // Update the last message (the AI placeholder) with new text
          _messages.last = ChatMessage(
            id: aiMsg.id,
            conversationId: aiMsg.conversationId,
            content: fullResponse, // The growing text
            isUser: false,
            timestamp: DateTime.now()
          );
        });
      },
      onDone: () async {
        // 5. Save final result to DB when done
        final finalMsg = ChatMessage(
            conversationId: _currentConversationId, content: fullResponse.trim(), isUser: false, timestamp: DateTime.now());
        await _db.insertMessage(finalMsg);
        
        setState(() {
          _isBusy = false;
        });
      },
      onError: (e) {
        setState(() {
           _status = "Error: $e";
           _isBusy = false;
        });
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("AI Companion", style: TextStyle(fontSize: 18)),
            Text(_isModelLoaded ? _loadedModelName : _status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300))
          ],
        ),
        actions: [
          // THE NEW BUTTON
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openModelManager,
          )
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("My Conversations"),
              accountEmail: Text("${_sidebarChats.length} saved chats"),
              currentAccountPicture: const CircleAvatar(child: Icon(Icons.history)),
            ),
            ListTile(leading: const Icon(Icons.add), title: const Text("New Chat"), onTap: _startNewChat),
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
                        if (chat['id'] == _currentConversationId) setState(() => _messages = []); 
                      },
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: _messages.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text(_isModelLoaded ? "Start chatting!" : "Load a model in Settings (top right)", style: const TextStyle(color: Colors.grey)),
                      ],
                    )
                  )
                : ListView.builder(
                    // 1. ANCHOR TO BOTTOM
                    reverse: true, 
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      // 2. FLIP DATA ORDER
                      // We want index 0 to be the NEWEST message from our list
                      final reversedIndex = _messages.length - 1 - index;
                      final msg = _messages[reversedIndex];

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
                          child: MarkdownBody(
                            data: msg.content,
                            selectable: true, // Allow copying text
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(fontSize: 16),
                              // Code block styling
                              code: TextStyle(
                                backgroundColor: msg.isUser ? Colors.indigo[300] : Colors.grey[200],
                                fontFamily: 'monospace',
                                fontSize: 14,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: msg.isUser ? Colors.indigo[300] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
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
                    decoration: const InputDecoration(hintText: "Type a message...", border: OutlineInputBorder()),
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