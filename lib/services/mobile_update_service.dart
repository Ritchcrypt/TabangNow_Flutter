import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

/// Validates remote version metadata without allowing non-HTTPS download links.
/// The production APK must explicitly supply API_BASE_URL at build time.
class MobileUpdateTransportPolicy {
  const MobileUpdateTransportPolicy._();

  static bool isAllowedApiRoot(
    String value, {
    required bool allowLoopbackHttp,
  }) {
    final uri = _parse(value);
    if (uri == null || (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery || uri.hasFragment) {
      return false;
    }
    if (uri.scheme == 'https') {
      return _isPublicHost(uri.host) && (!uri.hasPort || uri.port == 443);
    }
    return allowLoopbackHttp && uri.scheme == 'http' &&
        _isLoopbackHost(uri.host) && (!uri.hasPort || uri.port == 8000);
  }

  static bool isAllowedDownload(String value) {
    final uri = _parse(value);
    return uri != null && uri.scheme == 'https' &&
        _isPublicHost(uri.host) && (!uri.hasPort || uri.port == 443);
  }

  static Uri? _parse(String value) {
    if (value.isEmpty || value != value.trim() ||
        value.contains('\\') || RegExp(r'[\x00-\x20\x7f]').hasMatch(value)) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  static bool _isLoopbackHost(String host) {
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  static bool _isPublicHost(String host) {
    final lower = host.toLowerCase();
    if (_isLoopbackHost(lower) || lower.endsWith('.local') ||
        lower.startsWith('10.') || lower.startsWith('192.168.') ||
        lower.startsWith('127.') || lower.startsWith('169.254.') ||
        RegExp(r'^172\.(1[6-9]|2[0-9]|3[0-1])\.').hasMatch(lower)) {
      return false;
    }
    // No raw IP-address destinations or single-label names for public links.
    return lower.contains('.') && RegExp(r'^[a-z0-9][a-z0-9.-]*[a-z0-9]$').hasMatch(lower);
  }
}

class MobileUpdateService {
  const MobileUpdateService();

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
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

      // Local USB development may use loopback HTTP. Release builds fail
      // closed unless a public HTTPS API_BASE_URL was supplied explicitly.
      if (!MobileUpdateTransportPolicy.isAllowedApiRoot(
        baseUrl,
        allowLoopbackHttp: !kReleaseMode,
      )) {
        return const MobileUpdateCheck.unavailable();
      }

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
          !MobileUpdateTransportPolicy.isAllowedDownload(downloadUrl)) {
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
