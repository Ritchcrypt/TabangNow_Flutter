import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  AuthService({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  static const String _tokenKey = 'tabangnow_access_token';
  static String? _sessionToken;
  static const Duration _requestTimeout = Duration(seconds: 15);

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String deviceName,
    bool remember = false,
  }) async {
    late final http.Response response;

    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/auth/login'),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'email': email.trim(),
              'password': password,
              'device_name': deviceName.trim(),
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw AuthException(
        'The TabangNow server at $_baseUrl did not respond. For local physical-device testing, keep Laravel running on port 8000 and enable ADB reverse for tcp:8000.',
      );
    } on SocketException catch (exception) {
      throw AuthException(
        'Unable to reach the TabangNow server at $_baseUrl (${exception.message}). For a USB-connected Android device, run adb reverse tcp:8000 tcp:8000.',
      );
    } on http.ClientException catch (exception) {
      throw AuthException(
        'Unable to reach the TabangNow server at $_baseUrl (${exception.message}).',
      );
    }

    final data = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final token = data['access_token'];

      if (token is! String || token.isEmpty) {
        throw const AuthException('The server did not return an access token.');
      }

      _sessionToken = token;

      if (remember) {
        await _storage.write(key: _tokenKey, value: token);
      } else {
        await _storage.delete(key: _tokenKey);
      }

      return data;
    }

    throw AuthException(
      _extractErrorMessage(data),
      statusCode: response.statusCode,
    );
  }

  Future<String> requestPasswordReset({required String email}) async {
    late final http.Response response;

    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/auth/forgot-password'),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{'email': email.trim()}),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const AuthException(
        'Unable to connect to TabangNow right now. Please try again.',
      );
    } on SocketException {
      throw const AuthException(
        'Unable to connect to TabangNow right now. Please try again.',
      );
    } on http.ClientException {
      throw const AuthException(
        'Unable to connect to TabangNow right now. Please try again.',
      );
    }

    final data = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final message = data['message']?.toString().trim();

      return message == null || message.isEmpty
          ? 'A reset link will be sent if the account exists.'
          : message;
    }

    throw AuthException(
      _extractErrorMessage(data),
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> devSession() async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/auth/dev-session'),
      headers: const <String, String>{'Accept': 'application/json'},
    );

    final data = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final token = data['access_token'];

      if (token is! String || token.isEmpty) {
        throw const AuthException(
          'The local development session did not return an access token.',
        );
      }

      _sessionToken = token;
      await _storage.write(key: _tokenKey, value: token);

      return data;
    }

    throw AuthException(
      _extractErrorMessage(data),
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> me() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw const AuthException(
        'No authenticated session was found.',
        statusCode: 401,
      );
    }

    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/auth/me'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final data = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    await handleAuthorizationFailure(
      statusCode: response.statusCode,
      message: _extractErrorMessage(data),
    );

    throw AuthException(
      _extractErrorMessage(data),
      statusCode: response.statusCode,
    );
  }


  Future<void> presenceHeartbeat() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/presence/heartbeat'),
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
    } on SocketException {
    } on http.ClientException {
    }
  }
  Future<Map<String, dynamic>> dashboard() {
    return _authorizedGet('/api/v1/dashboard');
  }

  Future<Map<String, dynamic>> announcements() {
    return _authorizedGet('/api/v1/announcements');
  }

  Future<Map<String, dynamic>> emergencyHotlines() {
    return _authorizedGet('/api/v1/emergency-hotlines');
  }

  Future<Map<String, dynamic>> _authorizedGet(String path) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw const AuthException(
        'No authenticated session was found.',
        statusCode: 401,
      );
    }

    final response = await _client.get(
      Uri.parse('$_baseUrl$path'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final data = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    await handleAuthorizationFailure(
      statusCode: response.statusCode,
      message: _extractErrorMessage(data),
    );

    throw AuthException(
      _extractErrorMessage(data),
      statusCode: response.statusCode,
    );
  }

  Future<void> logout() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      await clearToken();
      return;
    }

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/v1/auth/logout'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 400 && response.statusCode != 401) {
        final data = _decodeResponse(response);

        throw AuthException(
          _extractErrorMessage(data),
          statusCode: response.statusCode,
        );
      }
    } finally {
      await clearToken();
    }
  }

  Future<String?> getToken() async {
    final sessionToken = _sessionToken;

    if (sessionToken != null && sessionToken.isNotEmpty) {
      return sessionToken;
    }

    final persistedToken = await _storage.read(key: _tokenKey);

    if (persistedToken != null && persistedToken.isNotEmpty) {
      _sessionToken = persistedToken;
    }

    return persistedToken;
  }

  Future<bool> hasToken() async {
    final token = await getToken();

    return token != null && token.isNotEmpty;
  }

  Future<void> handleAuthorizationFailure({
    required int statusCode,
    String? message,
  }) async {
    final normalizedMessage = message?.trim().toLowerCase() ?? '';
    final inactiveAccount =
        statusCode == 403 && normalizedMessage.contains('account is inactive');

    if (statusCode == 401 || inactiveAccount) {
      await clearToken();
    }
  }

  Future<void> clearToken() async {
    _sessionToken = null;
    await _storage.delete(key: _tokenKey);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return <String, dynamic>{};
    } on FormatException {
      throw AuthException(
        'The server returned an invalid response.',
        statusCode: response.statusCode,
      );
    }
  }

  String _extractErrorMessage(Map<String, dynamic> data) {
    final message = data['message'];

    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    final errors = data['errors'];

    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }

        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    return 'Unable to complete the request.';
  }
}

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  String get userMessage {
    final normalized = message.trim().toLowerCase();

    const technicalNetworkFragments = <String>[
      '127.0.0.1',
      'localhost',
      'connection refused',
      'connection reset',
      'connection timed out',
      'failed host lookup',
      'network is unreachable',
      'socketexception',
      'clientexception',
      'httpexception',
      'adb reverse',
      'tcp:8000',
      'api_base_url',
    ];

    if (technicalNetworkFragments.any(normalized.contains)) {
      return 'Unable to connect to TabangNow right now. Please try again.';
    }

    return message;
  }

  @override
  String toString() => message;
}
