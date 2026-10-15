import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class TanodRosterService {
  TanodRosterService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<Map<String, dynamic>> roster({String? search, int page = 1}) async {
    final parameters = <String, String>{'page': page.toString()};

    final normalizedSearch = search?.trim() ?? '';

    if (normalizedSearch.isNotEmpty) {
      parameters['search'] = normalizedSearch;
    }

    final uri = Uri.parse(
      '$baseUrl/api/v1/tanod-roster',
    ).replace(queryParameters: parameters);

    return _request(() async => _client.get(uri, headers: await _headers()));
  }

  Future<Map<String, dynamic>> create({
    required String fullName,
    String? contactNumber,
    String? email,
    String? purokAssignment,
    String? dateAppointed,
    required int barangayId,
    required String shift,
    required String status,
    bool autoDutyEnabled = false,
    String? notes,
  }) async {
    return _request(
      () async => _client.post(
        Uri.parse('$baseUrl/api/v1/tanod-roster'),
        headers: await _jsonHeaders(),
        body: jsonEncode(
          _payload(
            fullName: fullName,
            contactNumber: contactNumber,
            email: email,
            purokAssignment: purokAssignment,
            dateAppointed: dateAppointed,
            barangayId: barangayId,
            shift: shift,
            status: status,
            autoDutyEnabled: autoDutyEnabled,
            notes: notes,
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> update({
    required int tanodId,
    required String fullName,
    String? contactNumber,
    String? email,
    String? purokAssignment,
    String? dateAppointed,
    required int barangayId,
    required String shift,
    required String status,
    bool autoDutyEnabled = false,
    String? notes,
  }) async {
    return _request(
      () async => _client.patch(
        Uri.parse('$baseUrl/api/v1/tanod-roster/$tanodId'),
        headers: await _jsonHeaders(),
        body: jsonEncode(
          _payload(
            fullName: fullName,
            contactNumber: contactNumber,
            email: email,
            purokAssignment: purokAssignment,
            dateAppointed: dateAppointed,
            barangayId: barangayId,
            shift: shift,
            status: status,
            autoDutyEnabled: autoDutyEnabled,
            notes: notes,
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> delete(int tanodId) async {
    return _request(
      () async => _client.delete(
        Uri.parse('$baseUrl/api/v1/tanod-roster/$tanodId'),
        headers: await _headers(),
      ),
    );
  }

  Map<String, dynamic> _payload({
    required String fullName,
    String? contactNumber,
    String? email,
    String? purokAssignment,
    String? dateAppointed,
    required int barangayId,
    required String shift,
    required String status,
    bool autoDutyEnabled = false,
    String? notes,
  }) {
    return <String, dynamic>{
      'full_name': fullName.trim(),
      'contact_number': _nullableText(contactNumber),
      'email': _nullableText(email),
      'purok_assignment': _nullableText(purokAssignment),
      'date_appointed': _nullableText(dateAppointed),
      'barangay_id': barangayId,
      'shift': shift.trim(),
      'status': status.trim(),
      'auto_duty_enabled': autoDutyEnabled,
      'notes': _nullableText(notes),
    };
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim() ?? '';

    return normalized.isEmpty ? null : normalized;
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

    if (response.statusCode == 401 || response.statusCode == 403) {
      if (response.statusCode == 401) {
        await authService.clearToken();
      }
    }

    throw AuthException(_message(data), statusCode: response.statusCode);
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
        : 'The request could not be completed.';
  }
}
