import 'package:flutter/material.dart';

class ChatDrawer extends StatelessWidget {
  final List<Map<String, dynamic>> conversations;
  final int currentId;
  final VoidCallback onNewChat;
  final Function(int) onLoadChat;
  final Function(int) onDeleteChat;

  const ChatDrawer({
    super.key,
    required this.conversations,
    required this.currentId,
    required this.onNewChat,
    required this.onLoadChat,
    required this.onDeleteChat,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text("My Conversations"),
            accountEmail: Text("${conversations.length} saved chats"),
            currentAccountPicture: const CircleAvatar(child: Icon(Icons.history)),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text("New Chat"),
            onTap: onNewChat,
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final chat = conversations[index];
                final bool isSelected = chat['id'] == currentId;
                return ListTile(
                  title: Text(
                    chat['title'], 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                  selected: isSelected,
                  selectedTileColor: Colors.indigo.withOpacity(0.1),
                  onTap: () => onLoadChat(chat['id']),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 16, color: Colors.grey),
                    onPressed: () => onDeleteChat(chat['id']),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}