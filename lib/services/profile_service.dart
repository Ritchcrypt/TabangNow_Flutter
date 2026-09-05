import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ProfileService {
  ProfileService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<Map<String, dynamic>> show() {
    return _jsonRequest(
      () async => _client.get(
        Uri.parse('$baseUrl/api/v1/profile'),
        headers: await _headers(),
      ),
    );
  }

  Future<Map<String, dynamic>> update({
    required String name,
    required String email,
    String? contactNumber,
    String? address,
    String? profilePhotoPath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/profile/update'),
    );

    request.headers.addAll(await _headers());
    request.fields.addAll(<String, String>{
      'name': name.trim(),
      'email': email.trim(),
      'contact_number': contactNumber?.trim() ?? '',
      'address': address?.trim() ?? '',
    });

    if (profilePhotoPath != null && profilePhotoPath.trim().isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('profile_photo', profilePhotoPath),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  Future<Uint8List?> photoBytes() async {
    final uri = Uri.parse('$baseUrl/api/v1/profile/photo').replace(
      queryParameters: <String, String>{
        'v': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    final response = await _client.get(uri, headers: await _headers());

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes.isEmpty ? null : response.bodyBytes;
    }

    final data = _decode(response.body);
    final message = _message(data);
    await _clearOnlyIfUnauthenticated(response.statusCode);
    throw AuthException(message, statusCode: response.statusCode);
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) {
    return _jsonRequest(
      () async => _client.patch(
        Uri.parse('$baseUrl/api/v1/profile/password'),
        headers: await _jsonHeaders(),
        body: jsonEncode(<String, String>{
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': confirmation,
        }),
      ),
    );
  }

  Future<Map<String, dynamic>> signOutOtherDevices({required String password}) {
    return _jsonRequest(
      () async => _client.delete(
        Uri.parse('$baseUrl/api/v1/profile/other-sessions'),
        headers: await _jsonHeaders(),
        body: jsonEncode(<String, String>{'password': password}),
      ),
    );
  }

  Future<Map<String, dynamic>> deleteOwnAccount({
    required String password,
  }) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/api/v1/profile/self-delete'),
      headers: await _jsonHeaders(),
      body: jsonEncode(<String, String>{'password': password}),
    );

    final data = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await authService.clearToken();
      return data;
    }

    await _clearOnlyIfUnauthenticated(response.statusCode);
    throw AuthException(_message(data), statusCode: response.statusCode);
  }

  Future<Map<String, dynamic>> _jsonRequest(
    Future<http.Response> Function() request,
  ) async {
    final response = await request();
    return _handle(response);
  }

  Future<Map<String, dynamic>> _handle(http.Response response) async {
    final data = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    await _clearOnlyIfUnauthenticated(response.statusCode);
    throw AuthException(_message(data), statusCode: response.statusCode);
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

  Future<void> _clearOnlyIfUnauthenticated(int statusCode) async {
    if (statusCode == 401) {
      await authService.clearToken();
    }
  }

  Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return <String, dynamic>{};
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
        if (text.isNotEmpty) return text;
      }
    }

    final message = data['message']?.toString().trim() ?? '';
    return message.isEmpty ? 'Unable to complete the request.' : message;
  }
}
