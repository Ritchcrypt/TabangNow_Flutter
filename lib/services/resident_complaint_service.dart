import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ResidentComplaintService {
  ResidentComplaintService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<Map<String, dynamic>> index({int page = 1}) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/resident-complaints',
    ).replace(queryParameters: <String, String>{'page': page.toString()});

    return _request(() async => _client.get(uri, headers: await _headers()));
  }

  Future<Map<String, dynamic>> show(int complaintId) async {
    return _request(
      () async => _client.get(
        Uri.parse('$baseUrl/api/v1/resident-complaints/$complaintId'),
        headers: await _headers(),
      ),
    );
  }

  Future<Map<String, dynamic>> create({
    required String complainantName,
    String? contactNumber,
    required String complaintAddress,
    required String complaintDescription,
    String? evidencePath,
  }) async {
    final token = await _token();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/resident-complaints'),
    );

    request.headers.addAll(<String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    request.fields.addAll(<String, String>{
      'complainant_name': complainantName.trim(),
      'contact_number': contactNumber?.trim() ?? '',
      'complaint_address': complaintAddress.trim(),
      'complaint_description': complaintDescription.trim(),
    });

    if (evidencePath != null && evidencePath.trim().isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('evidence', evidencePath),
      );
    }

    return _streamRequest(request);
  }

  Future<Map<String, dynamic>> updateStatus({
    required int complaintId,
    required String status,
  }) async {
    return _request(
      () async => _client.patch(
        Uri.parse('$baseUrl/api/v1/resident-complaints/$complaintId/status'),
        headers: await _jsonHeaders(),
        body: jsonEncode(<String, dynamic>{'status': status}),
      ),
    );
  }

  Future<Map<String, dynamic>> uploadProof({
    required int complaintId,
    required String proofPicturePath,
    String? proofNote,
  }) async {
    final token = await _token();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/resident-complaints/$complaintId/proofs'),
    );

    request.headers.addAll(<String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    request.fields['proof_note'] = proofNote?.trim() ?? '';

    request.files.add(
      await http.MultipartFile.fromPath('proof_picture', proofPicturePath),
    );

    return _streamRequest(request);
  }

  Future<Map<String, dynamic>> delete(int complaintId) async {
    return _request(
      () async => _client.delete(
        Uri.parse('$baseUrl/api/v1/resident-complaints/$complaintId'),
        headers: await _headers(),
      ),
    );
  }

  Future<Uint8List> evidenceBytes(int complaintId) {
    return _fileBytes(
      '$baseUrl/api/v1/resident-complaints/$complaintId/evidence',
    );
  }

  Future<Uint8List> proofBytes(int proofId) {
    return _fileBytes(
      '$baseUrl/api/v1/resident-complaint-proofs/$proofId/file',
    );
  }

  Future<Uint8List> _fileBytes(String url) async {
    final response = await _client.get(
      Uri.parse(url),
      headers: await _headers(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    final data = _decode(response.body);

    throw AuthException(_message(data), statusCode: response.statusCode);
  }

  Future<Map<String, dynamic>> _streamRequest(
    http.MultipartRequest request,
  ) async {
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() request,
  ) async {
    return _handleResponse(await request());
  }

  Future<Map<String, String>> _jsonHeaders() async {
    return <String, String>{
      ...await _headers(),
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, String>> _headers() async {
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer ${await _token()}',
    };
  }

  Future<String> _token() async {
    final token = await authService.getToken();

    if (token == null || token.isEmpty) {
      throw const AuthException(
        'No authenticated development session was found.',
        statusCode: 401,
      );
    }

    return token;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final data = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    if (response.statusCode == 401) {
      await authService.clearToken();
    }

    throw AuthException(_message(data), statusCode: response.statusCode);
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
        : 'The resident complaint request could not be completed.';
  }
}
