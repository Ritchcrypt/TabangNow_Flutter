import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class DistressSignalService {
  DistressSignalService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<List<Map<String, dynamic>>> index() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/emergency-alerts'),
      headers: await _headers(),
    );

    final payload = await _decodeAuthorized(response);
    final rawData = payload['data'];

    if (rawData is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawData
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> show(int alertId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/emergency-alerts/$alertId'),
      headers: await _headers(),
    );

    final payload = await _decodeAuthorized(response);
    final rawData = payload['data'];

    return rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> acknowledge(int alertId) async {
    return _stateChange(alertId, 'acknowledge');
  }

  Future<Map<String, dynamic>> resolve(int alertId) async {
    return _stateChange(alertId, 'resolve');
  }

  Future<void> delete(int alertId) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/api/v1/emergency-alerts/$alertId'),
      headers: await _headers(),
    );

    await _decodeAuthorized(response);
  }

  Future<int> deleteAll() async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/api/v1/emergency-alerts'),
      headers: await _headers(),
    );

    final payload = await _decodeAuthorized(response);
    final rawData = payload['data'];

    if (rawData is! Map) {
      return 0;
    }

    final data = Map<String, dynamic>.from(rawData);
    return int.tryParse(data['deleted_count']?.toString() ?? '') ?? 0;
  }

  Future<Map<String, dynamic>> _stateChange(int alertId, String action) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/api/v1/emergency-alerts/$alertId/$action'),
      headers: await _headers(),
    );

    final payload = await _decodeAuthorized(response);
    final rawData = payload['data'];

    return rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
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

    if (response.statusCode == 401 || response.statusCode == 403) {
      if (response.statusCode == 401) {
        await authService.clearToken();
      }
    }

    throw AuthException(_message(data), statusCode: response.statusCode);
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
    final message = data['message']?.toString().trim();

    return message != null && message.isNotEmpty
        ? message
        : 'The Distress Signal request could not be completed.';
  }
}
