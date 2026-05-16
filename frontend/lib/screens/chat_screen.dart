import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'assessment_screen.dart';
import 'chat_history_screen.dart';
import 'helplines_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.userType,
    required this.ageRange,
    this.sessionId,
  });

  static const routeName = '/chat';
  final String userType;
  final String ageRange;
  final String? sessionId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  late String _sessionId;
  bool _isLoading = false;
  bool _showCrisisCard = false;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
    _loadPastMessages();
  }

  Future<void> _loadPastMessages() async {
    try {
      final history = await _api.getHistory();
      
      // Find the session matching our sessionId
      final session = history.firstWhere(
        (s) => (s as Map<String, dynamic>)['session_id'] == _sessionId,
        orElse: () => null,
      );
      
      if (session != null && mounted) {
        final messages = (session as Map<String, dynamic>)['messages'] as List<dynamic>? ?? [];
        setState(() {
          _messages.clear();
          for (final msg in messages) {
            final m = msg as Map<String, dynamic>;
            _messages.add({
              'role': m['role'] as String? ?? 'user',
              'content': m['content'] as String? ?? '',
            });
          }
        });
      }
    } catch (e) {
      // No past messages, start fresh
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await _api.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      // Add an empty assistant bubble we'll grow as deltas arrive.
      _messages.add({'role': 'assistant', 'content': ''});
      _controller.clear();
      _isLoading = true;
    });

    final assistantIdx = _messages.length - 1;
    final buf = StringBuffer();
    var gotAnything = false;

    try {
      await for (final event in _api.streamChat(
        message: text,
        userType: widget.userType.toLowerCase(),
        sessionId: _sessionId,
      )) {
        final type = event['event'] as String? ?? '';
        if (type == 'start') {
          final sid = event['session_id'] as String?;
          if (sid != null) _sessionId = sid;
        } else if (type == 'delta' || type == 'crisis') {
          buf.write(event['content'] as String? ?? '');
          if (type == 'crisis') {
            _showCrisisCard = true;
          }
          gotAnything = true;
          if (mounted) {
            setState(() {
              _messages[assistantIdx] = {'role': 'assistant', 'content': buf.toString()};
            });
          }
        } else if (type == 'end') {
          final sid = event['session_id'] as String?;
          if (sid != null) _sessionId = sid;
          final showCard = (event['show_helpline_card'] as bool?) ?? false;
          if (showCard && mounted) {
            setState(() => _showCrisisCard = true);
          }
        } else if (type == 'error') {
          throw Exception(event['detail'] as String? ?? 'Stream error');
        }
      }
    } on UnauthorizedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your session expired. Please log in again.')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    } catch (e) {
      if (!gotAnything && mounted) {
        setState(() {
          _messages[assistantIdx] = {
            'role': 'assistant',
            'content': 'Something went wrong. Please try again.',
          };
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = widget.userType == 'Student';
    return Scaffold(
      appBar: AppBar(
        title: Text('MindBridge Chat (${widget.userType})'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, HelplinesScreen.routeName),
            icon: const Icon(Icons.local_phone),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, ChatHistoryScreen.routeName),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _isLoadingHistory
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_showCrisisCard)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFB71C1C),
                    padding: const EdgeInsets.all(12),
                    child: const Text(
                      'Immediate Support: iCall 9152987821 | Emergency 112',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (isStudent)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, AssessmentScreen.routeName),
                        child: const Text('Take Assessment'),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final item = _messages[index];
                      final isUser = item['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFFD6EEFF) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(item['content'] ?? ''),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading ? null : _send,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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
