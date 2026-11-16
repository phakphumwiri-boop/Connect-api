import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

class IshApi {
  IshApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = (baseUrl ??
              const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'http://10.0.2.2:8000',
              ))
          .replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final String baseUrl;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<bool> checkHealth() async {
    final response = await _client
        .get(_uri('/health'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw IshApiException(
        'Backend health check failed (${response.statusCode}).',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['status'] == 'ok';
  }

  Future<String> sendMessage({
    required String sessionId,
    required String message,
  }) async {
    final response = await _client
        .post(
          _uri('/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'session_id': sessionId, 'message': message}),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IshApiException(
        'Chat request failed (${response.statusCode}).',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final reply = body['reply'];
    if (reply is! String || reply.trim().isEmpty) {
      throw const IshApiException('Backend returned an empty or invalid reply.');
    }
    return reply;
  }

  Future<List<ChatMessage>> getHistory(String sessionId) async {
    final response = await _client
        .get(_uri('/history/${Uri.encodeComponent(sessionId)}'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw IshApiException(
        'Could not load history (${response.statusCode}).',
      );
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }

  void close() => _client.close();
}

class IshApiException implements Exception {
  const IshApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
