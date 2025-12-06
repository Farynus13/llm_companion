import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'native_bridge.dart';
import 'models/chat_message.dart';
import 'models/model_config.dart';
import 'logic/prompt_engine.dart';
import 'services/database_service.dart';

// UI Components
import 'ui/model_sheet.dart';
import 'ui/chat_bubble.dart';
import 'ui/chat_drawer.dart';
import 'ui/chat_input.dart';
import 'ui/settings_sheet.dart';

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
  String _systemPrompt = "You are a helpful AI assistant.";

  @override
  void initState() {
    super.initState();
    _loadSidebar();
    _autoLoadLastModel();
    _loadPersona();
  }

  // --- LOGIC SECTION ---
  Future<void> _loadPersona() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _systemPrompt = prefs.getString('system_prompt') ?? "You are a helpful AI assistant.";
    });
  }

  Future<void> _autoLoadLastModel() async {
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString('last_model_id');
    
    if (lastId != null) {
      final config = ModelRegistry.findById(lastId);
      if (config != null) {
        final dir = await getApplicationDocumentsDirectory();
        final path = p.join(dir.path, config.filename);
        if (await File(path).exists()) {
          _loadModelInternal(path, config);
        } else {
          setState(() => _status = "Missing file for ${config.name}");
        }
      }
    } else {
      setState(() => _status = "Select a model to begin.");
    }
  }

  Future<void> _loadModelInternal(String path, ModelConfig config) async {
    setState(() { _status = "Loading ${config.name}..."; _isBusy = true; });
    
    _promptEngine.format = config.format;
    await Future.delayed(const Duration(milliseconds: 200)); // UI Breath
    bool success = await _bridge.loadModel(path);

    setState(() {
      _isModelLoaded = success;
      _loadedModelName = config.name;
      _status = success ? "Ready" : "Failed to load";
      _isBusy = false;
    });
  }

  Future<void> _loadSidebar() async {
    final chats = await _db.getConversations();
    setState(() => _sidebarChats = chats);
  }

  Future<void> _startNewChat() async {
    String title = "Chat #${_sidebarChats.length + 1}";
    int newId = await _db.createConversation(title);
    setState(() { _currentConversationId = newId; _messages = []; });
    await _loadSidebar();
    Navigator.pop(context); // Close drawer
  }

  Future<void> _loadChat(int id) async {
    final history = await _db.getMessages(id);
    setState(() { _currentConversationId = id; _messages = history; });
    Navigator.pop(context); // Close drawer
  }

  Future<void> _deleteChat(int id) async {
    await _db.deleteConversation(id);
    _loadSidebar();
    if (id == _currentConversationId) setState(() => _messages = []);
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;
    String text = _controller.text;
    _controller.clear();

    if (_currentConversationId == -1) {
      String title = text.length > 20 ? "${text.substring(0, 20)}..." : text;
      _currentConversationId = await _db.createConversation(title);
      await _loadSidebar();
    }
    
    final userMsg = ChatMessage(conversationId: _currentConversationId, content: text, isUser: true, timestamp: DateTime.now());
    await _db.insertMessage(userMsg);
    final aiMsg = ChatMessage(conversationId: _currentConversationId, content: "", isUser: false, timestamp: DateTime.now());
    
    setState(() {
      _messages.add(userMsg);
      _messages.add(aiMsg);
      _isBusy = true;
    });

    String formattedPrompt = _promptEngine.buildPrompt(
      _messages.sublist(0, _messages.length - 2), 
      text,
      systemOverride: _systemPrompt
    );

    String fullResponse = "";
    _bridge.generateStream(formattedPrompt, _promptEngine.stopToken).listen(
      (token) {
        fullResponse += token;
        setState(() {
          _messages.last = ChatMessage(
            id: aiMsg.id,
            conversationId: aiMsg.conversationId,
            content: fullResponse,
            isUser: false,
            timestamp: DateTime.now()
          );
        });
      },
      onDone: () async {
        final finalMsg = ChatMessage(conversationId: _currentConversationId, content: fullResponse.trim(), isUser: false, timestamp: DateTime.now());
        await _db.insertMessage(finalMsg);
        setState(() => _isBusy = false);
      },
      onError: (e) {
        setState(() { _status = "Error: $e"; _isBusy = false; });
      }
    );
  }

  // --- UI BUILD SECTION ---

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
          // Persona Button
          IconButton(
            icon: const Icon(Icons.psychology),
            tooltip: "AI Persona",
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true, // Allows keyboard to push it up
              builder: (ctx) => SettingsSheet(onSave: _loadPersona),
            ),
          ),
          // Model Button
          IconButton(
            icon: const Icon(Icons.download_for_offline),
            tooltip: "Manage Models",
            onPressed: () => showModalBottomSheet(
              context: context, 
              builder: (ctx) => ModelSheet(onModelSelected: _loadModelInternal)
            ),
          )
        ],
      ),
      // Clean Drawer Component
      drawer: ChatDrawer(
        conversations: _sidebarChats,
        currentId: _currentConversationId,
        onNewChat: _startNewChat,
        onLoadChat: _loadChat,
        onDeleteChat: _deleteChat,
      ),
      body: Column(
        children: [
          // Chat List
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: _messages.isEmpty 
                ? const Center(child: Text("Start a new conversation", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    reverse: true, // Auto-scroll
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final reversedIndex = _messages.length - 1 - index;
                      // Clean Bubble Component
                      return ChatBubble(message: _messages[reversedIndex]);
                    },
                  ),
            ),
          ),
          // Clean Input Component
          ChatInput(
            controller: _controller,
            isBusy: _isBusy,
            isModelLoaded: _isModelLoaded,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}