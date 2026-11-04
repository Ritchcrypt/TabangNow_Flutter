import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class DownloadedReportPdf {
  const DownloadedReportPdf({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

class ReportService {
  ReportService({required this.authService, http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<Map<String, dynamic>> index({
    required String period,
    required String metric,
    String? dateFrom,
    String? dateTo,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/reports').replace(
      queryParameters: _query(
        period: period,
        metric: metric,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ),
    );

    final response = await _client.get(uri, headers: await _headers());

    return _jsonResponse(response);
  }

  Future<DownloadedReportPdf> metricPdf({
    required String period,
    required String metric,
    String? dateFrom,
    String? dateTo,
  }) {
    final uri = Uri.parse('$baseUrl/api/v1/reports/pdf').replace(
      queryParameters: _query(
        period: period,
        metric: metric,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ),
    );

    return _pdfRequest(
      uri,
      fallbackFileName: 'tabangnow-$metric-report.pdf',
    );
  }

  Future<DownloadedReportPdf> selectedPdf({
    required String period,
    required String metric,
    required String selectionMode,
    required List<String> recordKeys,
    String? dateFrom,
    String? dateTo,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/reports/selection/pdf');
    final headers = await _headers();

    final response = await _client.post(
      uri,
      headers: <String, String>{
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'period': period,
        'metric': metric,
        'selection_mode': selectionMode,
        'records': recordKeys,
        if (period == 'custom' && dateFrom != null) 'date_from': dateFrom,
        if (period == 'custom' && dateTo != null) 'date_to': dateTo,
      }),
    );

    return _pdfResponse(
      response,
      fallbackFileName: 'tabangnow-$metric-selected-report.pdf',
    );
  }

  Map<String, String> _query({
    required String period,
    required String metric,
    String? dateFrom,
    String? dateTo,
  }) {
    return <String, String>{
      'period': period,
      'metric': metric,
      if (period == 'custom' && dateFrom != null) 'date_from': dateFrom,
      if (period == 'custom' && dateTo != null) 'date_to': dateTo,
    };
  }

  Future<DownloadedReportPdf> _pdfRequest(
    Uri uri, {
    required String fallbackFileName,
  }) async {
    final response = await _client.get(uri, headers: await _headers());

    return _pdfResponse(response, fallbackFileName: fallbackFileName);
  }

  Future<DownloadedReportPdf> _pdfResponse(
    http.Response response, {
    required String fallbackFileName,
  }) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';

      if (!contentType.contains('pdf')) {
        throw const AuthException('The server response was not a PDF report.');
      }

      return DownloadedReportPdf(
        bytes: response.bodyBytes,
        fileName: _fileNameFromHeaders(response.headers, fallbackFileName),
      );
    }

    if (response.statusCode == 401) {
      await authService.clearToken();
    }

    final data = _decode(response.body);

    throw AuthException(_message(data), statusCode: response.statusCode);
  }

  Future<Map<String, dynamic>> _jsonResponse(http.Response response) async {
    final data = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    if (response.statusCode == 401) {
      await authService.clearToken();
    }

    throw AuthException(_message(data), statusCode: response.statusCode);
  }

  Future<Map<String, String>> _headers() async {
    final token = await authService.getToken();

    if (token == null || token.isEmpty) {
      throw const AuthException(
        'No authenticated development session was found.',
        statusCode: 401,
      );
    }

    return <String, String>{
      'Accept': 'application/json, application/pdf',
      'Authorization': 'Bearer $token',
    };
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
      // The API may return a non-JSON error page. Fall through to a generic message.
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
        : 'The report request could not be completed.';
  }

  String _fileNameFromHeaders(Map<String, String> headers, String fallback) {
    final disposition = headers['content-disposition'] ?? '';

    final encodedMatch = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition);

    if (encodedMatch != null) {
      final raw = encodedMatch.group(1);

      if (raw != null && raw.isNotEmpty) {
        return _safeFileName(Uri.decodeComponent(raw), fallback);
      }
    }

    final quotedMatch = RegExp(
      r'filename="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(disposition);

    if (quotedMatch != null) {
      final raw = quotedMatch.group(1);

      if (raw != null && raw.isNotEmpty) {
        return _safeFileName(raw, fallback);
      }
    }

    final plainMatch = RegExp(
      r'filename=([^;]+)',
      caseSensitive: false,
    ).firstMatch(disposition);

    if (plainMatch != null) {
      final raw = plainMatch.group(1)?.trim();

      if (raw != null && raw.isNotEmpty) {
        return _safeFileName(raw, fallback);
      }
    }

    return _safeFileName(fallback, 'tabangnow-report.pdf');
  }

  String _safeFileName(String value, String fallback) {
    var fileName = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();

    if (fileName.isEmpty) {
      fileName = fallback;
    }

    if (!fileName.toLowerCase().endsWith('.pdf')) {
      fileName = '$fileName.pdf';
    }

    return fileName;
  }
}
