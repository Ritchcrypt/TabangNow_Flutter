import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class IncidentService {
  IncidentService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<Map<String, dynamic>> listIncidents({
    String search = '',
    int? categoryId,
    int? statusId,
    String? priority,
    int page = 1,
  }) async {
    final query = <String, String>{'page': page.toString()};

    final trimmedSearch = search.trim();
    if (trimmedSearch.isNotEmpty) {
      query['search'] = trimmedSearch;
    }

    if (categoryId != null) {
      query['category_id'] = categoryId.toString();
    }

    if (statusId != null) {
      query['status_id'] = statusId.toString();
    }

    final normalizedPriority = priority?.trim().toLowerCase() ?? '';
    if (normalizedPriority.isNotEmpty && normalizedPriority != 'all') {
      query['priority'] = normalizedPriority;
    }

    final uri = Uri.parse(
      '$baseUrl/api/v1/incidents',
    ).replace(queryParameters: query);

    return _authorizedJsonRequest(
      () async => _client.get(uri, headers: await _headers()),
    );
  }

  Future<Map<String, dynamic>> incidentOptions() async {
    return _authorizedJsonRequest(
      () async => _client.get(
        Uri.parse('$baseUrl/api/v1/incidents/options'),
        headers: await _headers(),
      ),
    );
  }

  Future<Map<String, dynamic>> incident(int incidentId) async {
    return _authorizedJsonRequest(
      () async => _client.get(
        Uri.parse('$baseUrl/api/v1/incidents/$incidentId'),
        headers: await _headers(),
      ),
    );
  }

  Future<Map<String, dynamic>> createIncident({
    required String title,
    required String description,
    required int categoryId,
    required int barangayId,
    required String priority,
    required String locationAddress,
    double? latitude,
    double? longitude,
    List<PlatformFile> evidence = const <PlatformFile>[],
  }) async {
    final token = await _requiredToken();

    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/incidents'))
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['incident_title'] = title.trim()
          ..fields['incident_description'] = description.trim()
          ..fields['category_id'] = categoryId.toString()
          ..fields['barangay_id'] = barangayId.toString()
          ..fields['priority'] = priority
          ..fields['location_address'] = locationAddress.trim();

    if (latitude != null) {
      request.fields['latitude'] = latitude.toString();
    }

    if (longitude != null) {
      request.fields['longitude'] = longitude.toString();
    }

    for (final file in evidence) {
      if (file.path != null && file.path!.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'evidence[]',
            file.path!,
            filename: file.name,
          ),
        );
        continue;
      }

      if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'evidence[]',
            file.bytes!,
            filename: file.name,
          ),
        );
        continue;
      }

      if (file.readStream != null) {
        request.files.add(
          http.MultipartFile(
            'evidence[]',
            file.readStream!,
            file.size,
            filename: file.name,
          ),
        );
      }
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return _decodeAuthorizedResponse(response);
  }

  Future<Map<String, dynamic>> updateStatus({
    required int incidentId,
    required int statusId,
    String? remarks,
    bool includeAssignedTo = false,
    int? assignedTo,
  }) async {
    final body = <String, dynamic>{'status_id': statusId};

    final trimmedRemarks = remarks?.trim() ?? '';
    if (trimmedRemarks.isNotEmpty) {
      body['remarks'] = trimmedRemarks;
    }

    if (includeAssignedTo) {
      body['assigned_to'] = assignedTo;
    }

    return _authorizedJsonRequest(
      () async => _client.patch(
        Uri.parse('$baseUrl/api/v1/incidents/$incidentId/status'),
        headers: await _jsonHeaders(),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> escalateIncident({
    required int incidentId,
    required String agency,
    String? reason,
  }) async {
    final body = <String, dynamic>{'agency': agency.trim()};

    final trimmedReason = reason?.trim() ?? '';
    if (trimmedReason.isNotEmpty) {
      body['reason'] = trimmedReason;
    }

    return _authorizedJsonRequest(
      () async => _client.post(
        Uri.parse('$baseUrl/api/v1/incidents/$incidentId/escalate'),
        headers: await _jsonHeaders(),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> addMessage({
    required int incidentId,
    required String message,
  }) async {
    return _authorizedJsonRequest(
      () async => _client.post(
        Uri.parse('$baseUrl/api/v1/incidents/$incidentId/messages'),
        headers: await _jsonHeaders(),
        body: jsonEncode(<String, dynamic>{'message': message.trim()}),
      ),
    );
  }

  Future<Map<String, dynamic>> deleteIncident({required int incidentId}) async {
    return _authorizedJsonRequest(
      () async => _client.delete(
        Uri.parse('$baseUrl/api/v1/incidents/$incidentId'),
        headers: await _headers(),
      ),
    );
  }

  Future<Map<String, dynamic>> addBarangay({required String name}) async {
    return _authorizedJsonRequest(
      () async => _client.post(
        Uri.parse('$baseUrl/api/v1/incidents/barangays'),
        headers: await _jsonHeaders(),
        body: jsonEncode(<String, dynamic>{'barangay_name': name.trim()}),
      ),
    );
  }

  Future<Map<String, dynamic>> deleteBarangay({required int barangayId}) async {
    return _authorizedJsonRequest(
      () async => _client.delete(
        Uri.parse('$baseUrl/api/v1/incidents/barangays/$barangayId'),
        headers: await _headers(),
      ),
    );
  }

  Future<Uint8List> evidenceBytes({
    required int incidentId,
    required int evidenceId,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/incidents/$incidentId/evidence/$evidenceId'),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    final data = _decodeJson(response.body);
    final message = _extractErrorMessage(data);

    await authService.handleAuthorizationFailure(
      statusCode: response.statusCode,
      message: message,
    );

    throw AuthException(message, statusCode: response.statusCode);
  }

  Future<Map<String, String>> _jsonHeaders() async {
    final headers = await _headers();

    return <String, String>{...headers, 'Content-Type': 'application/json'};
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

  Future<Map<String, dynamic>> _authorizedJsonRequest(
    Future<http.Response> Function() request,
  ) async {
    final response = await request();
    return _decodeAuthorizedResponse(response);
  }

  Future<Map<String, dynamic>> _decodeAuthorizedResponse(
    http.Response response,
  ) async {
    final data = _decodeJson(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final message = _extractErrorMessage(data);

    await authService.handleAuthorizationFailure(
      statusCode: response.statusCode,
      message: message,
    );

    throw AuthException(message, statusCode: response.statusCode);
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
