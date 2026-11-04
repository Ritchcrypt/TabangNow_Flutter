import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AnnouncementService {
  AnnouncementService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<Map<String, dynamic>> index({int page = 1}) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/announcements',
    ).replace(queryParameters: <String, String>{'page': page.toString()});

    return _request(() async => _client.get(uri, headers: await _headers()));
  }

  Future<Map<String, dynamic>> create({
    required String title,
    required String content,
    required String category,
    required String priority,
    required String audience,
    required List<int> barangayIds,
    required bool calamityMode,
    required bool showInWeatherFeed,
  }) async {
    return _request(
      () async => _client.post(
        Uri.parse('$baseUrl/api/v1/announcements'),
        headers: await _jsonHeaders(),
        body: jsonEncode(<String, dynamic>{
          'title': title.trim(),
          'content': content.trim(),
          'category': category,
          'priority': priority,
          'audience': audience,
          'barangay_ids': barangayIds,
          'activate_calamity_mode': calamityMode,
          'show_in_weather_feed': showInWeatherFeed,
        }),
      ),
    );
  }


  Future<List<Map<String, dynamic>>> barangayOptions() async {
    /*
     * Capstone 18 announcement targeting requires canonical barangay IDs.
     * The announcement API may expose them directly in options on newer
     * backend builds. For compatibility with the current feature branch,
     * reuse the established incident create-options endpoint, which already
     * returns the same canonical Dao barangay records to announcement
     * managers (admin/official roles).
     */
    final response = await _request(
      () async => _client.get(
        Uri.parse('$baseUrl/api/v1/incidents/options'),
        headers: await _headers(),
      ),
    );

    final data = _map(response['data']);
    final barangays = data['barangays'];

    if (barangays is! List) {
      return <Map<String, dynamic>>[];
    }

    return barangays
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) {
          final id = int.tryParse(item['id']?.toString() ?? '');
          final name = item['name']?.toString().trim() ?? '';
          return id != null && id > 0 && name.isNotEmpty;
        })
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> toggle(int announcementId) async {
    return _request(
      () async => _client.patch(
        Uri.parse('$baseUrl/api/v1/announcements/$announcementId/toggle'),
        headers: await _jsonHeaders(),
      ),
    );
  }

  Future<Map<String, dynamic>> delete(int announcementId) async {
    return _request(
      () async => _client.delete(
        Uri.parse('$baseUrl/api/v1/announcements/$announcementId'),
        headers: await _headers(),
      ),
    );
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

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() request,
  ) async {
    final response = await request();
    final data = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    if (response.statusCode == 401) {
      await authService.clearToken();
    }

    throw AuthException(_message(data), statusCode: response.statusCode);
  }


  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  Map<String, dynamic> _decode(String body) {
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

        final text = value?.toString().trim() ?? '';

        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    final message = data['message']?.toString().trim();

    return message != null && message.isNotEmpty
        ? message
        : 'The announcement request could not be completed.';
  }
}
