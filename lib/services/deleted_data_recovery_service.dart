import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class DeletedDataRecoveryService {
  DeletedDataRecoveryService({required this.authService, http.Client? client})
      : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<Map<String, dynamic>> index({
    int page = 1,
    String status = 'recoverable',
    String type = '',
    String search = '',
  }) {
    final query = <String, String>{'page': '$page', 'status': status};
    if (type.trim().isNotEmpty) query['type'] = type.trim();
    if (search.trim().isNotEmpty) query['search'] = search.trim();

    final url = Uri.parse('$baseUrl/api/v1/deleted-data-recovery')
        .replace(queryParameters: query);
    return _request(() async => _client.get(url, headers: await _headers()));
  }

  Future<Map<String, dynamic>> restore(int archiveId) {
    return _request(() async => _client.patch(
          Uri.parse('$baseUrl/api/v1/deleted-data-recovery/$archiveId/restore'),
          headers: await _headers(),
        ));
  }

  Future<Map<String, String>> _headers() async {
    final token = await authService.getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('No authenticated session was found.', statusCode: 401);
    }
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send,
  ) async {
    final response = await send();
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      data = <String, dynamic>{};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    await authService.handleAuthorizationFailure(
      statusCode: response.statusCode,
      message: data['message']?.toString(),
    );
    throw AuthException(
      data['message']?.toString() ?? 'Deleted Data Recovery is unavailable.',
      statusCode: response.statusCode,
    );
  }
}
