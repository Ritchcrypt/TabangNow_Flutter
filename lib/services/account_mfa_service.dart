import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// MFA is managed by the same Laravel account, never by a separate mobile DB.
class AccountMfaService {
  AccountMfaService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<Map<String, dynamic>> status() => _request('GET', '/status');

  Future<Map<String, dynamic>> begin(String password) =>
      _request('POST', '/begin', <String, String>{'password': password});

  Future<Map<String, dynamic>> confirm(String code) async {
    final result = await _request('POST', '/confirm', <String, String>{
      'code': code.trim(),
    });
    await _replaceAccessToken(result);
    return result;
  }

  Future<Map<String, dynamic>> regenerate({
    required String password,
    required String code,
  }) => _request('POST', '/recovery', <String, String>{
    'password': password,
    'code': code.trim(),
  });

  Future<Map<String, dynamic>> disable({
    required String password,
    required String code,
  }) async {
    final result = await _request('POST', '/disable', <String, String>{
      'password': password,
      'code': code.trim(),
    });
    await _replaceAccessToken(result);
    return result;
  }

  Future<void> _replaceAccessToken(Map<String, dynamic> result) async {
    final token = result['access_token'];
    if (token is! String || token.isEmpty) {
      // The server has revoked this token. Failing closed is safer than reusing it.
      await authService.clearToken();
      throw const AuthException(
        'Security change completed, but the new session could not be saved. Please sign in again.',
      );
    }
    await authService.replaceAccessToken(token);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String suffix, [
    Map<String, String>? fields,
  ]) async {
    final token = await authService.getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Please sign in to manage account security.', statusCode: 401);
    }
    final uri = Uri.parse('$_baseUrl/api/v1/profile/mfa$suffix');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (fields != null) 'Content-Type': 'application/json',
    };
    late final http.Response response;
    try {
      response = await (method == 'GET'
              ? _client.get(uri, headers: headers)
              : _client.post(uri, headers: headers, body: jsonEncode(fields)))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AuthException('MFA request timed out. Check your connection.');
    } on SocketException {
      throw const AuthException('Unable to connect to the TabangNow server.');
    } on http.ClientException {
      throw const AuthException('Unable to connect to the TabangNow server.');
    }
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
    } on FormatException {
      throw const AuthException('The server returned an invalid MFA response.');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    await authService.handleAuthorizationFailure(
      statusCode: response.statusCode,
      message: data['message']?.toString(),
    );
    final errors = data['errors'];
    String message = data['message']?.toString() ?? 'Unable to manage MFA.';
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) message = first.first.toString();
    }
    throw AuthException(message, statusCode: response.statusCode);
  }
}
