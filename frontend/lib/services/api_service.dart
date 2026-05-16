import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  ApiService({this.baseUrl = 'https://exempt-storage-seal-diamond.trycloudflare.com'});

  final String baseUrl;

  Future<Map<String, dynamic>> sendChat({
    required String message,
    required String userType,
    required String sessionId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'user_type': userType,
        'session_id': sessionId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Chat request failed: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> assess({
    required String assessmentType,
    required List<int> answers,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assess'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'assessment_type': assessmentType,
        'answers': answers,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Assessment failed: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getHistory() async {
    final response = await http.get(Uri.parse('$baseUrl/history'));
    if (response.statusCode != 200) {
      throw Exception('History request failed: ${response.body}');
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['sessions'] as List<dynamic>;
  }
}
