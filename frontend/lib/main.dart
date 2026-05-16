import 'dart:html' as html;

import 'package:flutter/material.dart';

import 'screens/assessment_screen.dart';
import 'screens/chat_history_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/helplines_screen.dart';
import 'screens/intake_screen.dart';
import 'screens/login_screen.dart';
import 'screens/results_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MindBridgeApp());
}

class MindBridgeApp extends StatefulWidget {
  const MindBridgeApp({super.key});

  @override
  State<MindBridgeApp> createState() => _MindBridgeAppState();
}

class _MindBridgeAppState extends State<MindBridgeApp> {
  final _apiService = ApiService();
  bool _isCheckingAuth = true;
  bool _isAuthenticated = false;
  String? _username;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    try {
      final hasToken = await _apiService.loadToken();
      if (hasToken) {
        final userInfo = await _apiService.getMe();
        setState(() {
          _isAuthenticated = true;
          _username = userInfo['username'] as String?;
        });
      }
    } catch (e) {
      // Silent fail - user is not authenticated
      html.window.localStorage.remove('auth_token');
      html.window.localStorage.remove('current_screen');
      html.window.localStorage.remove('chat_params');
    } finally {
      setState(() => _isCheckingAuth = false);
    }
  }

  Widget _getHomeScreen() {
    if (!_isAuthenticated) {
      return const LoginScreen();
    }
    // Always show intake after login/reload
    // User can navigate back to chat from there
    return const IntakeScreen();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

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
      home: _getHomeScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/intake': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return IntakeScreen(
            username: args?['username'] as String?,
            token: args?['token'] as String?,
          );
        },
        HelplinesScreen.routeName: (_) => const HelplinesScreen(),
        AssessmentScreen.routeName: (_) => const AssessmentScreen(),
        ChatHistoryScreen.routeName: (_) => const ChatHistoryScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == ChatScreen.routeName) {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => ChatScreen(
              userType: args['userType'] as String? ?? 'Student',
              ageRange: args['ageRange'] as String? ?? '18-25',
              sessionId: args['sessionId'] as String?,
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

