import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_message.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // 1. Open Database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'chat_history.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Table 1: Conversations (The list in the sidebar)
        await db.execute('''
          CREATE TABLE conversations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            last_updated TEXT
          )
        ''');

        // Table 2: Messages (The actual chat logs)
        await db.execute('''
          CREATE TABLE messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id INTEGER,
            content TEXT,
            is_user INTEGER,
            timestamp TEXT,
            FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // --- API FOR CONVERSATIONS ---

  // Create a new chat
  Future<int> createConversation(String title) async {
    final db = await database;
    return await db.insert('conversations', {
      'title': title,
      'last_updated': DateTime.now().toIso8601String(),
    });
  }

  // Get all chats for the sidebar
  Future<List<Map<String, dynamic>>> getConversations() async {
    final db = await database;
    return await db.query('conversations', orderBy: 'last_updated DESC');
  }

  // Delete a chat
  Future<void> deleteConversation(int id) async {
    final db = await database;
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  // --- API FOR MESSAGES ---

  Future<void> insertMessage(ChatMessage msg) async {
    final db = await database;
    await db.insert('messages', msg.toMap());
    
    // Update the "last_updated" time of the conversation
    await db.update(
      'conversations', 
      {'last_updated': DateTime.now().toIso8601String()},
      where: 'id = ?', 
      whereArgs: [msg.conversationId]
    );
  }

  Future<List<ChatMessage>> getMessages(int conversationId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC', // Oldest first
    );

    return List.generate(maps.length, (i) => ChatMessage.fromMap(maps[i]));
  }
}