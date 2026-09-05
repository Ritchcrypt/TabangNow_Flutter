import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class MobileSosException implements Exception {
  const MobileSosException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MobileSosLocation {
  const MobileSosLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String source;

  bool get isLastKnown => source == 'last_known';
}

class MobileSosSendResult {
  const MobileSosSendResult({required this.alertCode, required this.status});

  final String alertCode;
  final String status;
}

class MobileSosService {
  MobileSosService({
    required this.authService,
    http.Client? client,
    FlutterSecureStorage? secureStorage,
  }) : _client = client ?? http.Client(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const String _installationIdKey =
      'tabangnow_emergency_installation_id';
  static const String _emergencyTokenKey = 'tabangnow_emergency_device_token';

  final AuthService authService;
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;

  Future<Map<String, String>> prefillIdentity() async {
    try {
      final response = await authService.me();
      final rawUser = response['user'];

      if (rawUser is! Map) {
        return const <String, String>{};
      }

      final user = Map<String, dynamic>.from(rawUser);
      final name = user['name']?.toString().trim() ?? '';
      final contactValue = user['contact_number'] ?? user['phone'];
      final contactNumber = contactValue?.toString().trim() ?? '';

      return <String, String>{
        if (name.isNotEmpty) 'name': name,
        if (contactNumber.isNotEmpty) 'contact_number': contactNumber,
      };
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<MobileSosLocation> acquireLocation() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const MobileSosException(
        'Location permission is required to send a distress signal.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const MobileSosException(
        'Location permission is permanently denied. Enable location permission in Android app settings and try again.',
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (serviceEnabled) {
      try {
        final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );

        return MobileSosLocation(
          latitude: current.latitude,
          longitude: current.longitude,
          accuracyMeters: current.accuracy,
          source: 'current',
        );
      } catch (_) {
      }
    }

    try {
      final lastKnown = await Geolocator.getLastKnownPosition();

      if (lastKnown != null) {
        return MobileSosLocation(
          latitude: lastKnown.latitude,
          longitude: lastKnown.longitude,
          accuracyMeters: lastKnown.accuracy,
          source: 'last_known',
        );
      }
    } catch (_) {
    }

    if (!serviceEnabled) {
      throw const MobileSosException(
        'Location is turned off and no last-known location is available. Turn on Location/GPS, then retry.',
      );
    }

    throw const MobileSosException(
      'Unable to get the current or last-known location. Move to an area with a clearer GPS signal and retry.',
    );
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<MobileSosSendResult> send({
    required String name,
    required String emergencyDetails,
    required String contactNumber,
    required MobileSosLocation location,
  }) async {
    final installationId = await _installationId();
    final emergencyToken = await _bestEffortEmergencyToken(installationId);

    final payload = <String, dynamic>{
      'request_id': _requestId(),
      'installation_id': installationId,
      'name': name.trim(),
      'emergency_details': emergencyDetails.trim(),
      'contact_number': contactNumber.trim(),
      'latitude': location.latitude,
      'longitude': location.longitude,
      'accuracy_meters': location.accuracyMeters,
      'location_source': location.source,
    };

    if (emergencyToken != null && emergencyToken.isNotEmpty) {
      payload['emergency_token'] = emergencyToken;
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/emergency/sos'),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    final data = _decode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MobileSosException(_message(data));
    }

    final rawAlert = data['data'];
    final alert = rawAlert is Map
        ? Map<String, dynamic>.from(rawAlert)
        : <String, dynamic>{};

    return MobileSosSendResult(
      alertCode: (alert['alert_code']?.toString() ?? 'SOS').trim(),
      status: (alert['status']?.toString() ?? 'active').trim(),
    );
  }

  Future<String> _installationId() async {
    final existing =
        (await _secureStorage.read(key: _installationIdKey))?.trim() ?? '';

    if (existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final suffix = List<int>.generate(
      12,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

    final generated =
        'android-${DateTime.now().microsecondsSinceEpoch}-$suffix';

    await _secureStorage.write(key: _installationIdKey, value: generated);

    return generated;
  }

  String _requestId() {
    final random = Random.secure();
    final suffix = List<int>.generate(
      8,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

    return 'sos-${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  Future<String?> _bestEffortEmergencyToken(String installationId) async {
    var stored =
        (await _secureStorage.read(key: _emergencyTokenKey))?.trim() ?? '';

    try {
      final authToken = await authService.getToken();

      if (authToken == null || authToken.trim().isEmpty) {
        return stored.isEmpty ? null : stored;
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/emergency/device/enroll'),
        headers: <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authToken.trim()}',
        },
        body: jsonEncode(<String, dynamic>{
          'installation_id': installationId,
          'device_name': 'TabangNow Android',
          'platform': 'android',
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = _decode(response.body);
        final rawData = data['data'];
        final enrollment = rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : <String, dynamic>{};
        final newToken = enrollment['emergency_token']?.toString().trim() ?? '';

        if (newToken.isNotEmpty) {
          stored = newToken;
          await _secureStorage.write(key: _emergencyTokenKey, value: stored);
        }
      }
    } catch (_) {
    }

    return stored.isEmpty ? null : stored;
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
        : 'The distress signal could not be sent.';
  }
}
