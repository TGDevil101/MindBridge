import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  static const routeName = '/history';

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final _api = ApiService();
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _sessions = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions[index] as Map<String, dynamic>;
                return ListTile(
                  title: Text('Session: ${session['session_id'] ?? '-'}'),
                  subtitle: Text('User type: ${session['user_type'] ?? '-'}'),
                );
              },
            ),
    );
  }
}
