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
  });

  static const routeName = '/chat';
  final String userType;
  final String ageRange;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  bool _isLoading = false;
  bool _showCrisisCard = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _controller.clear();
      _isLoading = true;
    });

    try {
      final result = await _api.sendChat(
        message: text,
        userType: widget.userType.toLowerCase(),
        sessionId: _sessionId,
      );
      setState(() {
        _sessionId = result['session_id'] as String? ?? _sessionId;
        _messages.add({'role': 'assistant', 'content': result['response'] as String? ?? ''});
        _showCrisisCard = (result['show_helpline_card'] as bool?) ?? false;
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'Something went wrong: $e'});
      });
    } finally {
      setState(() => _isLoading = false);
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
        ],
      ),
      body: Column(
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
