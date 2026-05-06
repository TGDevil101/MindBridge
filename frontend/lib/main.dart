import 'package:flutter/material.dart';

import 'screens/assessment_screen.dart';
import 'screens/chat_history_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/helplines_screen.dart';
import 'screens/intake_screen.dart';
import 'screens/results_screen.dart';

void main() {
  runApp(const MindBridgeApp());
}

class MindBridgeApp extends StatelessWidget {
  const MindBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindBridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D9A),
          primary: const Color(0xFF2E7D9A),
          secondary: const Color(0xFF5EA37A),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4FAFF),
        useMaterial3: true,
      ),
      home: const IntakeScreen(),
      routes: {
        HelplinesScreen.routeName: (_) => const HelplinesScreen(),
        AssessmentScreen.routeName: (_) => const AssessmentScreen(),
        ChatHistoryScreen.routeName: (_) => const ChatHistoryScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == ChatScreen.routeName) {
          final args = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder: (_) => ChatScreen(
              userType: args['userType'] ?? 'Student',
              ageRange: args['ageRange'] ?? '18-25',
            ),
          );
        }
        if (settings.name == ResultsScreen.routeName) {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(builder: (_) => ResultsScreen(result: args));
        }
        return null;
      },
    );
  }
}
