import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class PublicBrandingData {
  const PublicBrandingData({
    required this.systemName,
    required this.systemSubtitle,
  });

  final String systemName;
  final String systemSubtitle;
}

class PublicBrandingLogoService {
  PublicBrandingLogoService({http.Client? client})
    : _client = client ?? http.Client();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const Duration _requestTimeout = Duration(seconds: 10);

  final http.Client _client;

  Future<PublicBrandingData> fetchBranding() async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/api/v1/public/system-branding'),
          headers: const <String, String>{
            'Accept': 'application/json',
            'Cache-Control': 'no-cache',
          },
        )
        .timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PublicBrandingLogoException(
        'Unable to load the TabangNow system branding.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    final payload = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    final rawData = payload['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    final systemName = data['system_name']?.toString().trim() ?? '';
    final systemSubtitle = data['system_subtitle']?.toString().trim() ?? '';

    return PublicBrandingData(
      systemName: systemName.isEmpty ? 'TabangNow' : systemName,
      systemSubtitle: systemSubtitle.isEmpty ? 'Dao, Capiz' : systemSubtitle,
    );
  }

  Future<Uint8List?> fetchLogoBytes() async {
    final uri = Uri.parse('$_baseUrl/system-branding/logo').replace(
      queryParameters: <String, String>{
        'mobile_v': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    final response = await _client
        .get(
          uri,
          headers: const <String, String>{
            'Accept': 'image/png,image/jpeg,image/webp,image/*;q=0.8,*/*;q=0.1',
            'Cache-Control': 'no-cache',
          },
        )
        .timeout(_requestTimeout);

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PublicBrandingLogoException(
        'Unable to load the TabangNow system logo.',
        statusCode: response.statusCode,
      );
    }

    var bytes = Uint8List.fromList(response.bodyBytes);

    if (bytes.isEmpty) {
      return null;
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      bytes = Uint8List.fromList(bytes.sublist(3));
    }

    if (!_looksLikeSupportedImage(bytes)) {
      throw const PublicBrandingLogoException(
        'The TabangNow logo response was not a supported image.',
      );
    }

    return bytes;
  }

  bool _looksLikeSupportedImage(Uint8List bytes) {
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;

    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;

    final isWebp =
        bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;

    return isPng || isJpeg || isWebp;
  }
}

class PublicBrandingLogoException implements Exception {
  const PublicBrandingLogoException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
