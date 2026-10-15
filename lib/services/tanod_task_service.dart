import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class TanodTaskService {
  TanodTaskService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<Map<String, dynamic>> tasks({int page = 1}) {
    final uri = Uri.parse(
      '$baseUrl/api/v1/tanod-tasks',
    ).replace(queryParameters: <String, String>{'page': page.toString()});

    return _request(() async => _client.get(uri, headers: await _headers()));
  }

  Future<Map<String, dynamic>> createTask({
    required String title,
    String? description,
    String? location,
    required int barangayId,
    DateTime? taskDateTime,
    DateTime? dueAt,
    required String priority,
  }) {
    return _request(
      () async => _client.post(
        Uri.parse('$baseUrl/api/v1/tanod-tasks'),
        headers: await _jsonHeaders(),
        body: jsonEncode(<String, dynamic>{
          'title': title.trim(),
          'description': _nullable(description),
          'location': _nullable(location),
          'barangay_id': barangayId,
          'task_datetime': taskDateTime?.toIso8601String(),
          'due_at': dueAt?.toIso8601String(),
          'priority': priority,
        }),
      ),
    );
  }

  Future<Map<String, dynamic>> taskDetails(int taskId) {
    return _request(
      () async => _client.get(
        Uri.parse('$baseUrl/api/v1/tanod-tasks/$taskId'),
        headers: await _headers(),
      ),
    );
  }

  Future<Map<String, dynamic>> closeTask(int taskId) {
    return _request(
      () async => _client.patch(
        Uri.parse('$baseUrl/api/v1/tanod-tasks/$taskId/close'),
        headers: await _jsonHeaders(),
      ),
    );
  }

  Future<Map<String, dynamic>> cancelTask(int taskId) {
    return _request(
      () async => _client.patch(
        Uri.parse('$baseUrl/api/v1/tanod-tasks/$taskId/cancel'),
        headers: await _jsonHeaders(),
      ),
    );
  }

  Future<Map<String, dynamic>> deleteTask(int taskId) {
    return _request(
      () async => _client.delete(
        Uri.parse('$baseUrl/api/v1/tanod-tasks/$taskId'),
        headers: await _headers(),
      ),
    );
  }

  Future<Map<String, dynamic>> respond({
    required int responseId,
    required String responseStatus,
    String? responseNote,
  }) {
    return _request(
      () async => _client.patch(
        Uri.parse('$baseUrl/api/v1/tanod-tasks/responses/$responseId'),
        headers: await _jsonHeaders(),
        body: jsonEncode(<String, dynamic>{
          'response_status': responseStatus,
          'response_note': _nullable(responseNote),
        }),
      ),
    );
  }

  String? _nullable(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Future<Map<String, String>> _headers() async {
    final token = await authService.getToken();

    if (token == null || token.isEmpty) {
      throw const AuthException(
        'No authenticated session was found.',
        statusCode: 401,
      );
    }

    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _jsonHeaders() async {
    return <String, String>{
      ...await _headers(),
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() request,
  ) async {
    final response = await request();
    final data = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    if (response.statusCode == 401) {
      await authService.clearToken();
    }

    throw AuthException(_message(data), statusCode: response.statusCode);
  }

  Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    return <String, dynamic>{};
  }

  String _message(Map<String, dynamic> data) {
    final errors = data['errors'];

    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }

        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    final message = data['message']?.toString().trim() ?? '';
    return message.isEmpty ? 'The request could not be completed.' : message;
  }
}
