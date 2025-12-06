import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/model_config.dart';

class ModelSheet extends StatefulWidget {
  final Function(String path, ModelConfig config) onModelSelected;

  const ModelSheet({super.key, required this.onModelSelected});

  @override
  State<ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends State<ModelSheet> {
  final Map<String, double> _downloadProgress = {}; 
  final Map<String, bool> _isDownloading = {};
  
  // Track which files exist on disk
  final Set<String> _existingFiles = {};

  @override
  void initState() {
    super.initState();
    _checkExistingFiles();
  }

  // Check which models are already downloaded
  Future<void> _checkExistingFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final newSet = <String>{};
    
    for (var model in ModelRegistry.models) {
      final file = File(p.join(dir.path, model.filename));
      if (await file.exists()) {
        newSet.add(model.id);
      }
    }
    
    if (mounted) {
      setState(() => _existingFiles.addAll(newSet));
    }
  }

  Future<void> _handleModelClick(ModelConfig config) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, config.filename));

    if (await file.exists()) {
      _selectModel(file.path, config);
    } else {
      _downloadModel(config, file);
    }
  }

  Future<void> _deleteModel(ModelConfig config) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, config.filename));
    
    if (await file.exists()) {
      await file.delete();
      setState(() => _existingFiles.remove(config.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Deleted ${config.name}")));
    }
  }

  Future<void> _downloadModel(ModelConfig config, File targetFile) async {
    setState(() {
      _isDownloading[config.id] = true;
      _downloadProgress[config.id] = 0.0;
    });

    final IOSink sink = targetFile.openWrite();
    
    try {
      final request = http.Request('GET', Uri.parse(config.url));
      final response = await http.Client().send(request);
      final contentLength = response.contentLength ?? 1;

      double received = 0;

      await for (var chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        setState(() {
          _downloadProgress[config.id] = received / contentLength;
        });
      }

      await sink.flush();
      await sink.close();

      if (mounted) {
        setState(() {
          _isDownloading[config.id] = false;
          _existingFiles.add(config.id);
        });
        _selectModel(targetFile.path, config);
      }

    } catch (e) {
      await sink.close();
      // CLEANUP: Delete partial file if download failed
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      
      if (mounted) {
        setState(() => _isDownloading[config.id] = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download failed: $e")));
      }
    }
  }

  Future<void> _selectModel(String path, ModelConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_model_id', config.id);

    widget.onModelSelected(path, config);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Select AI Model", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: ModelRegistry.models.length,
              itemBuilder: (context, index) {
                final model = ModelRegistry.models[index];
                final isDownloading = _isDownloading[model.id] ?? false;
                final isDownloaded = _existingFiles.contains(model.id);
                final progress = _downloadProgress[model.id] ?? 0.0;

                return Card(
                  child: ListTile(
                    title: Text(model.name),
                    subtitle: isDownloading 
                        ? LinearProgressIndicator(value: progress)
                        : Text(model.filename),
                    onTap: isDownloading ? null : () => _handleModelClick(model),
                    // TRAILING ICON LOGIC
                    trailing: isDownloading
                        ? Text("${(progress * 100).toInt()}%")
                        : isDownloaded
                            ? IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteModel(model),
                              )
                            : const Icon(Icons.download_for_offline),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}