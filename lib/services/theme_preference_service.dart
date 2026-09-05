import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ThemePreferenceService {
  ThemePreferenceService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<Map<String, dynamic>> load() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/theme-preference'),
      headers: await _headers(),
    );

    return _decodeAuthorized(response);
  }

  Future<Map<String, dynamic>> update({
    required String mode,
    String? customColor,
  }) async {
    final body = <String, dynamic>{'theme_mode': mode};

    if (customColor != null && customColor.trim().isNotEmpty) {
      body['theme_custom_color'] = customColor.trim();
    }

    final response = await _client.patch(
      Uri.parse('$baseUrl/api/v1/theme-preference'),
      headers: await _jsonHeaders(),
      body: jsonEncode(body),
    );

    return _decodeAuthorized(response);
  }

  Future<Map<String, String>> _jsonHeaders() async {
    return <String, String>{
      ...await _headers(),
      'Content-Type': 'application/json',
    };
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

  Future<Map<String, dynamic>> _decodeAuthorized(http.Response response) async {
    final data = _decodeJson(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final message = _message(data);

    await authService.handleAuthorizationFailure(
      statusCode: response.statusCode,
      message: message,
    );

    throw AuthException(message, statusCode: response.statusCode);
  }

  Map<String, dynamic> _decodeJson(String body) {
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

        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
    }

    final message = data['message']?.toString().trim();

    return message != null && message.isNotEmpty
        ? message
        : 'The theme preference could not be updated.';
  }
}
