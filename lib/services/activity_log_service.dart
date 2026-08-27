import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ActivityLogService {
  ActivityLogService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<Map<String, dynamic>> index({
    int page = 1,
    int perPage = 50,
    String search = '',
    String category = '',
    String event = '',
    int? actorId,
    String dateFrom = '',
    String dateTo = '',
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    void addIfNotEmpty(String key, String value) {
      final normalized = value.trim();

      if (normalized.isNotEmpty) {
        query[key] = normalized;
      }
    }

    addIfNotEmpty('search', search);
    addIfNotEmpty('category', category);
    addIfNotEmpty('event', event);
    addIfNotEmpty('date_from', dateFrom);
    addIfNotEmpty('date_to', dateTo);

    if (actorId != null && actorId > 0) {
      query['actor_id'] = actorId.toString();
    }

    final uri = Uri.parse(
      '$baseUrl/api/v1/activity-logs',
    ).replace(queryParameters: query);

    return _request(() async => _client.get(uri, headers: await _headers()));
  }

  Future<Map<String, dynamic>> deleteAll() {
    return _request(
      () async => _client.delete(
        Uri.parse('$baseUrl/api/v1/activity-logs'),
        headers: await _headers(),
      ),
    );
  }

  Future<Map<String, dynamic>> show(int activityLogId) {
    return _request(
      () async => _client.get(
        Uri.parse('$baseUrl/api/v1/activity-logs/$activityLogId'),
        headers: await _headers(),
      ),
    );
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

  Future<Map<String, String>> _headers() async {
    final token = await authService.getToken();

    if (token == null || token.isEmpty) {
      throw const AuthException(
        'No authenticated development session was found.',
        statusCode: 401,
      );
    }

    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Invalid/non-JSON errors use the fallback message below.
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

    final message = data['message']?.toString().trim();

    return message != null && message.isNotEmpty
        ? message
        : 'The Activity Logs request could not be completed.';
  }
}
