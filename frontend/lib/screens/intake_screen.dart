import 'package:flutter/material.dart';

import 'chat_screen.dart';

class IntakeScreen extends StatefulWidget {
  final String? username;
  final String? token;

  const IntakeScreen({
    super.key,
    this.username,
    this.token,
  });

  static const routeName = '/intake';

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  String? _userType;
  String? _ageRange;

  @override
  Widget build(BuildContext context) {
    final canContinue = _userType != null && _ageRange != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MindBridge Intake'),
        actions: widget.username != null
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      widget.username!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Who are you using MindBridge as?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _userType,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Student', child: Text('Student')),
                    DropdownMenuItem(value: 'Parent', child: Text('Parent')),
                  ],
                  onChanged: (value) => setState(() => _userType = value),
                ),
                const SizedBox(height: 20),
                const Text(
                  'What is your age range?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _ageRange,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Under 13', child: Text('Under 13')),
                    DropdownMenuItem(value: '13-17', child: Text('13–17')),
                    DropdownMenuItem(value: '18-25', child: Text('18–25')),
                    DropdownMenuItem(value: '26+', child: Text('26+')),
                  ],
                  onChanged: (value) => setState(() => _ageRange = value),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: !canContinue
                      ? null
                      : () {
                          if (_ageRange == 'Under 13') {
                            showDialog<void>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Age Restriction'),
                                content: const Text(
                                  'This app is designed for users aged 13 and above. '
                                  'Please ask a parent or trusted adult for support.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }
                          Navigator.pushNamed(
                            context,
                            ChatScreen.routeName,
                            arguments: {
                              'userType': _userType!,
                              'ageRange': _ageRange!,
                            },
                          );
                        },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
