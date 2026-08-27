import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class DownloadedUserExport {
  const DownloadedUserExport({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

class UserManagementService {
  UserManagementService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<Map<String, dynamic>> index({
    int page = 1,
    int perPage = 25,
    String search = '',
    String role = 'all',
    String status = 'all',
    String date = 'all',
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    if (role != 'all') {
      query['role'] = role;
    }

    if (status != 'all') {
      query['status'] = status;
    }

    if (date != 'all') {
      query['date'] = date;
    }

    final uri = Uri.parse(
      '$baseUrl/api/v1/users',
    ).replace(queryParameters: query);

    return _jsonRequest(
      () async => _client.get(uri, headers: await _headers()),
    );
  }


  Future<Map<String, dynamic>> presence() {
    return _jsonRequest(
      () async => _client.get(
        Uri.parse('$baseUrl/api/v1/presence/users'),
        headers: await _headers(),
      ),
    );
  }
  Future<Map<String, dynamic>> show(int userId) {
    return _jsonRequest(
      () async => _client.get(
        Uri.parse('$baseUrl/api/v1/users/$userId'),
        headers: await _headers(),
      ),
    );
  }

  Future<Map<String, dynamic>> create({
    required String name,
    required String email,
    String? contactNumber,
    int? barangayId,
    String? address,
    required String role,
    required String password,
    String? profilePhotoPath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/users'),
    );

    request.headers.addAll(await _headers());

    request.fields.addAll(<String, String>{
      'name': name.trim(),
      'email': email.trim(),
      'contact_number': contactNumber?.trim() ?? '',
      'barangay_id': barangayId?.toString() ?? '',
      'address': address?.trim() ?? '',
      'role': role,
      'password': password,
    });

    if (profilePhotoPath != null && profilePhotoPath.trim().isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('profile_photo', profilePhotoPath),
      );
    }

    return _multipartRequest(request);
  }

  Future<Map<String, dynamic>> update({
    required int userId,
    required String name,
    required String email,
    String? contactNumber,
    int? barangayId,
    String? address,
    required String role,
    String? profilePhotoPath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/users/$userId/update'),
    );

    request.headers.addAll(await _headers());

    request.fields.addAll(<String, String>{
      'name': name.trim(),
      'email': email.trim(),
      'contact_number': contactNumber?.trim() ?? '',
      'barangay_id': barangayId?.toString() ?? '',
      'address': address?.trim() ?? '',
      'role': role,
    });

    if (profilePhotoPath != null && profilePhotoPath.trim().isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('profile_photo', profilePhotoPath),
      );
    }

    return _multipartRequest(request);
  }

  Future<Map<String, dynamic>> activate(int userId) {
    return _jsonRequest(
      () async => _client.patch(
        Uri.parse('$baseUrl/api/v1/users/$userId/activate'),
        headers: await _headers(),
      ),
    );
  }

  Future<Map<String, dynamic>> deactivate(int userId) {
    return _jsonRequest(
      () async => _client.patch(
        Uri.parse('$baseUrl/api/v1/users/$userId/deactivate'),
        headers: await _headers(),
      ),
    );
  }

  Future<Map<String, dynamic>> sendPasswordResetLink(int userId) {
    return _jsonRequest(
      () async => _client.patch(
        Uri.parse('$baseUrl/api/v1/users/$userId/reset-password'),
        headers: await _headers(),
      ),
    );
  }

  Future<Map<String, dynamic>> delete(int userId) {
    return _jsonRequest(
      () async => _client.delete(
        Uri.parse('$baseUrl/api/v1/users/$userId'),
        headers: await _headers(),
      ),
    );
  }

  Future<Uint8List> profilePhotoBytes(int userId) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/$userId/profile-photo')
        .replace(
          queryParameters: <String, String>{
            'v': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );

    final response = await _client.get(uri, headers: await _headers());

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    if (response.statusCode == 401) {
      await authService.clearToken();
    }

    throw AuthException(
      _message(_decode(response.body)),
      statusCode: response.statusCode,
    );
  }

  Future<DownloadedUserExport> export({
    String search = '',
    String role = 'all',
    String status = 'all',
    String date = 'all',
  }) async {
    final query = <String, String>{};

    if (search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    if (role != 'all') {
      query['role'] = role;
    }

    if (status != 'all') {
      query['status'] = status;
    }

    if (date != 'all') {
      query['date'] = date;
    }

    final uri = Uri.parse(
      '$baseUrl/api/v1/users/export',
    ).replace(queryParameters: query);

    final response = await _client.get(
      uri,
      headers: await _headers(accept: 'text/csv, application/json'),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';

      if (!contentType.contains('csv')) {
        throw const AuthException(
          'The server response was not a CSV user export.',
        );
      }

      return DownloadedUserExport(
        bytes: response.bodyBytes,
        fileName: _fileNameFromHeaders(response.headers, 'users-export.csv'),
      );
    }

    if (response.statusCode == 401) {
      await authService.clearToken();
    }

    throw AuthException(
      _message(_decode(response.body)),
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> _multipartRequest(
    http.MultipartRequest request,
  ) async {
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    return _handleJsonResponse(response);
  }

  Future<Map<String, dynamic>> _jsonRequest(
    Future<http.Response> Function() request,
  ) async {
    return _handleJsonResponse(await request());
  }

  Future<Map<String, dynamic>> _handleJsonResponse(
    http.Response response,
  ) async {
    final data = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    if (response.statusCode == 401) {
      await authService.clearToken();
    }

    throw AuthException(_message(data), statusCode: response.statusCode);
  }

  Future<Map<String, String>> _headers({
    String accept = 'application/json',
  }) async {
    final token = await authService.getToken();

    if (token == null || token.isEmpty) {
      throw const AuthException(
        'No authenticated development session was found.',
        statusCode: 401,
      );
    }

    return <String, String>{'Accept': accept, 'Authorization': 'Bearer $token'};
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
      // CSV/binary response bodies do not need JSON parsing.
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
        : 'The User Management request could not be completed.';
  }

  String _fileNameFromHeaders(Map<String, String> headers, String fallback) {
    final disposition = headers['content-disposition'] ?? '';

    final encoded = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition);

    if (encoded != null) {
      final raw = encoded.group(1);

      if (raw != null && raw.isNotEmpty) {
        return _safeFileName(Uri.decodeComponent(raw), fallback);
      }
    }

    final quoted = RegExp(
      r'filename="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(disposition);

    if (quoted != null) {
      return _safeFileName(quoted.group(1) ?? fallback, fallback);
    }

    return _safeFileName(fallback, 'users-export.csv');
  }

  String _safeFileName(String value, String fallback) {
    var fileName = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();

    if (fileName.isEmpty) {
      fileName = fallback;
    }

    if (!fileName.toLowerCase().endsWith('.csv')) {
      fileName = '$fileName.csv';
    }

    return fileName;
  }
}
