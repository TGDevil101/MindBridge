import 'dart:convert';
import 'dart:html' as html;

import 'package:http/http.dart' as http;

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Session expired. Please log in again.']);
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService({String baseUrl = 'https://memorabilia-jet-retail-show.trycloudflare.com'}) {
    _instance.baseUrl = baseUrl;
    return _instance;
  }

  ApiService._internal();

  late String baseUrl;
  String? token;

  Future<bool> loadToken() async {
    token = html.window.localStorage['auth_token'];
    return token != null;
  }

  Future<void> logout() async {
    token = null;
    html.window.localStorage.remove('auth_token');
  }

  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Login failed');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    token = data['access_token'] as String;
    html.window.localStorage['auth_token'] = token!;
    return data;
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Registration failed');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get user info');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendChat({
    required String message,
    required String userType,
    required String sessionId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: _getHeaders(),
      body: jsonEncode({
        'message': message,
        'user_type': userType,
        'session_id': sessionId,
      }),
    );

    if (response.statusCode == 401) {
      await logout();
      throw UnauthorizedException();
    }
    if (response.statusCode != 200) {
      throw Exception('Chat request failed: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Stream chat tokens as they're generated. Yields one event map per
  /// NDJSON line from the backend. Event shapes:
  ///   {'event':'start', 'session_id':'...'}
  ///   {'event':'crisis', 'content':'...', 'show_helpline_card':true}
  ///   {'event':'delta', 'content':'...'}
  ///   {'event':'end', 'session_id':'...', 'crisis':bool, 'show_helpline_card':bool}
  ///   {'event':'error', 'detail':'...'}
  Stream<Map<String, dynamic>> streamChat({
    required String message,
    required String userType,
    required String sessionId,
  }) async* {
    final request = http.Request('POST', Uri.parse('$baseUrl/chat/stream'));
    request.headers.addAll(_getHeaders());
    request.body = jsonEncode({
      'message': message,
      'user_type': userType,
      'session_id': sessionId,
    });

    final client = http.Client();
    try {
      final streamed = await client.send(request);

      if (streamed.statusCode == 401) {
        await logout();
        throw UnauthorizedException();
      }
      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        throw Exception('Stream request failed (${streamed.statusCode}): $body');
      }

      // Buffer partial lines across chunks.
      String buffer = '';
      await for (final chunk in streamed.stream.transform(utf8.decoder)) {
        buffer += chunk;
        while (true) {
          final newlineIdx = buffer.indexOf('\n');
          if (newlineIdx < 0) break;
          final line = buffer.substring(0, newlineIdx).trim();
          buffer = buffer.substring(newlineIdx + 1);
          if (line.isEmpty) continue;
          try {
            yield jsonDecode(line) as Map<String, dynamic>;
          } catch (_) {
            // skip malformed line
          }
        }
      }
      // Flush any trailing line.
      if (buffer.trim().isNotEmpty) {
        try {
          yield jsonDecode(buffer.trim()) as Map<String, dynamic>;
        } catch (_) {}
      }
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> assess({
    required String assessmentType,
    required List<int> answers,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assess'),
      headers: _getHeaders(),
      body: jsonEncode({
        'assessment_type': assessmentType,
        'answers': answers,
      }),
    );

    if (response.statusCode == 401) {
      await logout();
      throw UnauthorizedException();
    }
    if (response.statusCode != 200) {
      throw Exception('Assessment failed: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getHistory() async {
    final response = await http.get(
      Uri.parse('$baseUrl/history'),
      headers: _getHeaders(),
    );
    if (response.statusCode == 401) {
      await logout();
      throw UnauthorizedException();
    }
    if (response.statusCode != 200) {
      throw Exception('History request failed: ${response.body}');
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['sessions'] as List<dynamic>;
  }

  Future<void> deleteSession(String sessionId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/history/$sessionId'),
      headers: _getHeaders(),
    );
    if (response.statusCode == 401) {
      await logout();
      throw UnauthorizedException();
    }
    if (response.statusCode != 200) {
      throw Exception('Delete failed: ${response.body}');
    }
  }
}
