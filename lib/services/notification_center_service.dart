import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class NotificationOpenTarget {
  const NotificationOpenTarget({required this.module, this.sourceId});

  final String module;
  final int? sourceId;

  factory NotificationOpenTarget.fromJson(Map<String, dynamic> json) {
    final rawId = json['source_id'];

    return NotificationOpenTarget(
      module: (json['module']?.toString() ?? 'dashboard').trim(),
      sourceId: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''),
    );
  }
}

class NotificationCenterService {
  NotificationCenterService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<Map<String, dynamic>> bell() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/notifications'),
      headers: await _headers(),
    );

    return _decodeAuthorized(response);
  }

  Future<Map<String, dynamic>> pulse() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/notifications/pulse'),
      headers: await _headers(),
    );

    return _decodeAuthorized(response);
  }

  Future<Map<String, dynamic>> markAllRead() async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/notifications/read-all'),
      headers: await _headers(),
    );

    return _decodeAuthorized(response);
  }

  Future<Map<String, dynamic>> deleteNotification(int notificationId) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/api/v1/notifications/$notificationId'),
      headers: await _headers(),
    );

    return _decodeAuthorized(response);
  }

  Future<NotificationOpenTarget> open(int notificationId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/notifications/$notificationId/open'),
      headers: await _headers(),
    );

    final data = await _decodeAuthorized(response);
    final rawData = data['data'];
    final payload = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    final rawTarget = payload['target'];
    final target = rawTarget is Map
        ? Map<String, dynamic>.from(rawTarget)
        : <String, dynamic>{};

    return NotificationOpenTarget.fromJson(target);
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
      await authService.clearToken();
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
        : 'The notification request could not be completed.';
  }
}
