import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Uses the same Laravel system_settings.dashboard_welcome_path as the website.
/// All endpoints require Sanctum bearer authentication; upload is admin-only.
class DashboardWelcomePhotoService {
  DashboardWelcomePhotoService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<String> version() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/dashboard/welcome-photo/status'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final payload = await _parse(response);
    return payload['version']?.toString() ?? '';
  }

  Future<Uint8List> photoBytes() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/dashboard/welcome-photo/image'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    await authService.handleAuthorizationFailure(statusCode: response.statusCode);
    throw AuthException('Unable to load the shared dashboard photo.',
      statusCode: response.statusCode);
  }

  Future<void> upload(PlatformFile file) async {
    final token = await authService.getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Please log in again.', statusCode: 401);
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/dashboard/welcome-photo'),
    )
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';

    if (file.path != null && file.path!.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath(
        'welcome_image', file.path!, filename: file.name,
      ));
    } else if (file.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'welcome_image', file.bytes!, filename: file.name,
      ));
    } else if (file.readStream != null) {
      request.files.add(http.MultipartFile(
        'welcome_image', file.readStream!, file.size, filename: file.name,
      ));
    } else {
      throw const AuthException('Cannot read the selected image.');
    }

    final streamed = await request.send().timeout(const Duration(seconds: 40));
    final response = await http.Response.fromStream(streamed);
    await _parse(response);
  }

  Future<Map<String, String>> _headers() async {
    final token = await authService.getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Please log in again.', statusCode: 401);
    }
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'Cache-Control': 'no-cache',
    };
  }

  Future<Map<String, dynamic>> _parse(http.Response response) async {
    Map<String, dynamic> data = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } on FormatException {
      // The error below remains user-readable if the server returns HTML.
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    final message = data['message']?.toString().trim();
    await authService.handleAuthorizationFailure(
      statusCode: response.statusCode,
      message: message,
    );
    throw AuthException(
      message != null && message.isNotEmpty
          ? message : 'Unable to update the shared dashboard photo.',
      statusCode: response.statusCode,
    );
  }
}
