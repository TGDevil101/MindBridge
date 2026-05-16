import 'package:flutter/material.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.result});

  static const routeName = '/results';
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final score = result['score'];
    final band = result['band'];
    final summary = result['summary'] ?? '';
    final showIcall = (result['show_icall'] as bool?) ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Assessment Results')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Score: $score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Band: $band', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(summary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This is NOT a diagnosis. Please speak to a qualified professional.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (showIcall)
              const Card(
                color: Color(0xFFE8F5E9),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Support: iCall 9152987821',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
