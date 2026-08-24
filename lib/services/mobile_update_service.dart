import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

enum MobileUpdateRequirement { none, optional, required, unavailable }

class MobileUpdateCheck {
  const MobileUpdateCheck({
    required this.requirement,
    required this.installedVersion,
    required this.installedBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minimumSupportedBuildNumber,
    required this.message,
    required this.downloadUrl,
  });

  const MobileUpdateCheck.unavailable()
    : requirement = MobileUpdateRequirement.unavailable,
      installedVersion = '',
      installedBuildNumber = 0,
      latestVersion = '',
      latestBuildNumber = 0,
      minimumSupportedBuildNumber = 0,
      message = '',
      downloadUrl = '';

  final MobileUpdateRequirement requirement;
  final String installedVersion;
  final int installedBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final int minimumSupportedBuildNumber;
  final String message;
  final String downloadUrl;
}

class MobileUpdatePolicy {
  const MobileUpdatePolicy._();

  static MobileUpdateRequirement evaluate({
    required int currentBuildNumber,
    required int latestBuildNumber,
    required int minimumSupportedBuildNumber,
  }) {
    if (currentBuildNumber < minimumSupportedBuildNumber) {
      return MobileUpdateRequirement.required;
    }

    if (currentBuildNumber < latestBuildNumber) {
      return MobileUpdateRequirement.optional;
    }

    return MobileUpdateRequirement.none;
  }
}

class MobileUpdateService {
  const MobileUpdateService();

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://scsis-production-ac26.up.railway.app',
  );

  Future<MobileUpdateCheck> check() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final installedBuildNumber = int.tryParse(packageInfo.buildNumber);

      if (installedBuildNumber == null || installedBuildNumber < 1) {
        return const MobileUpdateCheck.unavailable();
      }

      final baseUrl = _apiBaseUrl.endsWith('/')
          ? _apiBaseUrl.substring(0, _apiBaseUrl.length - 1)
          : _apiBaseUrl;

      final response = await http
          .get(
            Uri.parse('$baseUrl/api/v1/mobile/version'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return const MobileUpdateCheck.unavailable();
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const MobileUpdateCheck.unavailable();
      }

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return const MobileUpdateCheck.unavailable();
      }

      final latestBuildNumber = _asPositiveInt(data['latest_build_number']);
      final minimumSupportedBuildNumber = _asPositiveInt(
        data['minimum_supported_build_number'],
      );
      final latestVersion = data['latest_version']?.toString().trim() ?? '';
      final message = data['message']?.toString().trim() ?? '';
      final downloadUrl = data['download_url']?.toString().trim() ?? '';

      if (latestBuildNumber == null ||
          minimumSupportedBuildNumber == null ||
          latestVersion.isEmpty ||
          downloadUrl.isEmpty) {
        return const MobileUpdateCheck.unavailable();
      }

      final requirement = MobileUpdatePolicy.evaluate(
        currentBuildNumber: installedBuildNumber,
        latestBuildNumber: latestBuildNumber,
        minimumSupportedBuildNumber: minimumSupportedBuildNumber,
      );

      return MobileUpdateCheck(
        requirement: requirement,
        installedVersion: packageInfo.version,
        installedBuildNumber: installedBuildNumber,
        latestVersion: latestVersion,
        latestBuildNumber: latestBuildNumber,
        minimumSupportedBuildNumber: minimumSupportedBuildNumber,
        message: message.isEmpty
            ? 'A newer version of TabangNow is available.'
            : message,
        downloadUrl: downloadUrl,
      );
    } on Object {
      return const MobileUpdateCheck.unavailable();
    }
  }

  int? _asPositiveInt(Object? value) {
    final parsed = switch (value) {
      int number => number,
      String text => int.tryParse(text),
      _ => null,
    };

    if (parsed == null || parsed < 1) {
      return null;
    }

    return parsed;
  }
}
