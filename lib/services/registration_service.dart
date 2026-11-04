import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class RegistrationException implements Exception {
  const RegistrationException(this.message, {this.statusCode});

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
      'server did not respond at http',
      'unable to reach http',
    ];

    if (technicalNetworkFragments.any(normalized.contains)) {
      return 'Unable to connect to TabangNow right now. Please try again.';
    }

    return message;
  }

  @override
  String toString() => message;
}

class RegistrationService {
  RegistrationService({http.Client? client})
    : _client = client ?? http.Client();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const Duration _requestTimeout = Duration(seconds: 15);

  final http.Client _client;

  Future<List<Map<String, dynamic>>> fetchBarangays() async {
    late final http.Response response;

    final endpoint = Uri.parse('$_baseUrl/api/v1/auth/barangays');

    try {
      response = await _client
          .get(
            endpoint,
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const RegistrationException(
        'Unable to load barangays right now. Please retry.',
      );
    } on SocketException {
      throw const RegistrationException(
        'Unable to connect to TabangNow right now. Please try again.',
      );
    } on http.ClientException {
      throw const RegistrationException(
        'Unable to connect to TabangNow right now. Please try again.',
      );
    }

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RegistrationException(
        _errorMessage(data),
        statusCode: response.statusCode,
      );
    }

    final raw = data['data'];

    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> registerResident({
    required String name,
    required String email,
    required String contactNumber,
    required String address,
    required String dateOfBirth,
    required bool ageConfirmation,
    int? barangayId,
    required String password,
    required String passwordConfirmation,
  }) async {
    late final http.Response response;

    final endpoint = Uri.parse('$_baseUrl/api/v1/auth/register');

    try {
      response = await _client
          .post(
            endpoint,
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'name': name.trim(),
              'email': email.trim(),
              'contact_number': contactNumber.trim(),
              'address': address.trim(),
              'barangay_id': ?barangayId,
              'date_of_birth': dateOfBirth.trim(),
              'age_confirmation': ageConfirmation,
              'password': password,
              'password_confirmation': passwordConfirmation,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw RegistrationException(
        'The TabangNow server did not respond at $_baseUrl. Make sure Laravel is running on port 8000.',
      );
    } on SocketException catch (exception) {
      throw RegistrationException(
        'Unable to reach $_baseUrl (${exception.message}).',
      );
    } on http.ClientException catch (exception) {
      throw RegistrationException(
        'Unable to reach $_baseUrl (${exception.message}).',
      );
    }

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw RegistrationException(
      _errorMessage(data),
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      throw RegistrationException(
        response.statusCode == 404
            ? 'Mobile registration is not available on this server yet.'
            : 'The TabangNow server returned an invalid registration response (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
  }

  String _errorMessage(Map<String, dynamic> data) {
    final errors = data['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }

    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    return 'Unable to create the resident account.';
  }
}
