import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../core/global_branding_logo_controller.dart';
import 'auth_service.dart';

class BrandingService {
  BrandingService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<Map<String, dynamic>> branding() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/system-branding'),
      headers: await _headers(),
    );

    return _decodeAuthorizedResponse(response);
  }

  Future<Uint8List> logoBytes() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/system-branding/logo'),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final bytes = response.bodyBytes;

      if (bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF) {
        return Uint8List.fromList(bytes.sublist(3));
      }

      return bytes;
    }

    if (response.statusCode == 401) {
      await authService.clearToken();
    }

    throw AuthException(
      _extractErrorMessage(_decodeJson(response.body)),
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> updateBranding({
    required String systemName,
    required String systemSubtitle,
    PlatformFile? logo,
    bool removeLogo = false,
  }) async {
    final token = await _requiredToken();

    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/api/v1/system-branding'),
          )
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['system_name'] = systemName.trim()
          ..fields['system_subtitle'] = systemSubtitle.trim()
          ..fields['remove_logo'] = removeLogo ? '1' : '0';

    if (logo != null && !removeLogo) {
      if (logo.path != null && logo.path!.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'system_logo',
            logo.path!,
            filename: logo.name,
          ),
        );
      } else if (logo.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'system_logo',
            logo.bytes!,
            filename: logo.name,
          ),
        );
      } else if (logo.readStream != null) {
        request.files.add(
          http.MultipartFile(
            'system_logo',
            logo.readStream!,
            logo.size,
            filename: logo.name,
          ),
        );
      }
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = await _decodeAuthorizedResponse(response);

    await GlobalBrandingLogoController.instance.refresh();

    return data;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _requiredToken();

    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<String> _requiredToken() async {
    final token = await authService.getToken();

    if (token == null || token.isEmpty) {
      throw const AuthException(
        'No authenticated session was found.',
        statusCode: 401,
      );
    }

    return token;
  }

  Future<Map<String, dynamic>> _decodeAuthorizedResponse(
    http.Response response,
  ) async {
    final data = _decodeJson(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    if (response.statusCode == 401) {
      await authService.clearToken();
    }

    throw AuthException(
      _extractErrorMessage(data),
      statusCode: response.statusCode,
    );
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

  String _extractErrorMessage(Map<String, dynamic> data) {
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

    if (message != null && message.isNotEmpty) {
      return message;
    }

    return 'The request could not be completed.';
  }
}
