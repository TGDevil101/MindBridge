import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../services/api_service.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  static const routeName = '/history';

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final _api = ApiService();  // Factory constructor returns singleton
  bool _loading = true;
  List<dynamic> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sessions = await _api.getHistory();
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sessions = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteSession(String sessionId, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure you want to delete this chat session? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteSession(sessionId);
      if (mounted) {
        setState(() => _sessions.removeAt(index));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(
                  child: Text('No chat history yet'),
                )
              : ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index] as Map<String, dynamic>;
                    final messages = session['messages'] as List<dynamic>? ?? [];
                    final createdAt = session['created_at'] as String? ?? 'Unknown date';
                    final sessionId = (session['session_id'] as String? ?? '').substring(0, 8);

                    return ExpansionTile(
                      title: Text('Session ${sessionId}...'),
                      subtitle: Text(createdAt),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteSession(session['session_id'] as String, index),
                      ),
                      children: [
                        ...messages.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No messages in this session'),
                              )
                            ]
                          : messages.map<Widget>((msg) {
                              final msgMap = msg as Map<String, dynamic>;
                              final role = msgMap['role'] as String? ?? 'unknown';
                              final content = msgMap['content'] as String? ?? '';
                              final isUser = role == 'user';

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Align(
                                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                                    ),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isUser
                                          ? const Color(0xFFD6EEFF)
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(content),
                                  ),
                                ),
                              );
                            }).toList(),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                ChatScreen.routeName,
                                arguments: {
                                  'userType': 'Student',
                                  'ageRange': '18-25',
                                  'sessionId': session['session_id'] as String,
                                },
                              );
                            },
                            child: const Text('Continue this chat'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
