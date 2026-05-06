import 'package:flutter/material.dart';

class HelplinesScreen extends StatelessWidget {
  const HelplinesScreen({super.key});

  static const routeName = '/helplines';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Helplines')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('iCall: 9152987821', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Vandrevala Foundation: 1860-2662-345', style: TextStyle(fontSize: 16)),
            SizedBox(height: 12),
            Text('You can also speak to your school counsellor or a trusted adult.'),
          ],
        ),
      ),
    );
  }
}
