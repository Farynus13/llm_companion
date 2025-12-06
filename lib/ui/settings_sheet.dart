import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsSheet extends StatefulWidget {
  final VoidCallback onSave;

  const SettingsSheet({super.key, required this.onSave});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final TextEditingController _controller = TextEditingController();
  
  // Default persona
  static const String _defaultPrompt = "You are a helpful AI assistant.";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _controller.text = prefs.getString('system_prompt') ?? _defaultPrompt;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('system_prompt', _controller.text.trim());
    widget.onSave(); // Notify main app to reload
    Navigator.pop(context);
  }

  Future<void> _resetDefault() async {
    setState(() => _controller.text = _defaultPrompt);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 16, 
        left: 16, 
        right: 16, 
        bottom: MediaQuery.of(context).viewInsets.bottom + 16 // Handle keyboard
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("AI Persona", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton(onPressed: _resetDefault, child: const Text("Reset"))
            ],
          ),
          const SizedBox(height: 10),
          const Text("Define who the AI is (System Prompt):", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: "e.g., You are a senior Python developer...",
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: const Text("Save Configuration"),
            ),
          ),
        ],
      ),
    );
  }
}