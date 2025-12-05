class ChatMessage {
  final int? id;          // Database ID
  final int conversationId; // Which chat does this belong to?
  final String content;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    this.id,
    required this.conversationId,
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  // Convert to Map (for Saving)
  Map<String, dynamic> toMap() {
    return {
      'conversation_id': conversationId,
      'content': content,
      'is_user': isUser ? 1 : 0, // SQLite doesn't have booleans, use 0/1
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Create from Map (for Loading)
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      conversationId: map['conversation_id'],
      content: map['content'],
      isUser: map['is_user'] == 1,
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}