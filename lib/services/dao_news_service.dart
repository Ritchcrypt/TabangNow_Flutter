import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Mobile access to the SAME curated and signed Dao news records as Laravel.
/// No local article database, photo scraping, or external RSS feed.
class DaoNewsService {
  DaoNewsService({required this.authService, http.Client? client})
      : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL', defaultValue: 'http://127.0.0.1:8000',
  );

  final AuthService authService;
  final http.Client _client;

  Future<List<DaoNewsStory>> stories() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/dashboard/dao-news'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final data = await _parse(response);
    final items = data['data'];
    if (items is! List) return <DaoNewsStory>[];
    return items.whereType<Map>().take(9).map(
      (item) => DaoNewsStory.fromJson(Map<String, dynamic>.from(item)),
    ).where((story) => story.safeUri != null).toList(growable: false);
  }

  Future<Map<String, dynamic>> manage() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/dashboard/dao-news/manage'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 20));
    return _parse(response);
  }

  Future<void> act(String action, {String? id, String? url,
      String? topic, String? published, bool confirmed = false}) async {
    final fields = <String, dynamic>{'action': action};
    if (id != null) fields['id'] = id;
    if (url != null) fields['url'] = url;
    if (topic != null) fields['topic'] = topic;
    if (published != null) fields['published'] = published;
    if (confirmed) {
      fields['source_checked'] = true;
      fields['dao_relevance_checked'] = true;
    }
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/dashboard/dao-news/manage'),
      headers: <String, String>{...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode(fields),
    ).timeout(const Duration(seconds: 25));
    await _parse(response);
  }

  Future<Map<String, String>> _headers() async {
    final token = await authService.getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Please sign in again.', statusCode: 401);
    }
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'Cache-Control': 'no-cache',
    };
  }

  Future<Map<String, dynamic>> _parse(http.Response response) async {
    Map<String, dynamic> data = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } on FormatException {
      // Laravel can return an HTML error response while local server is down.
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    final message = data['message']?.toString().trim();
    await authService.handleAuthorizationFailure(
      statusCode: response.statusCode,
      message: message,
    );
    throw AuthException(
      message != null && message.isNotEmpty
          ? message : 'Dao community updates are unavailable.',
      statusCode: response.statusCode,
    );
  }
}

class DaoNewsStory {
  const DaoNewsStory({
    required this.title,
    required this.url,
    required this.source,
    this.published,
  });
  final String title;
  final String url;
  final String source;
  final String? published;

  factory DaoNewsStory.fromJson(Map<String, dynamic> data) {
    return DaoNewsStory(
      title: data['title']?.toString() ?? 'Dao, Capiz',
      url: data['url']?.toString() ?? '',
      source: data['source']?.toString() ?? '',
      published: data['published']?.toString(),
    );
  }

  /// Extra mobile defense; publisher allowlist remains authoritative in Laravel.
  Uri? get safeUri {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty ||
        uri.host.isEmpty || (uri.hasPort && uri.port != 443)) {
      return null;
    }
    const hosts = <String>{
      'pia.gov.ph', 'pna.gov.ph', 'pagasa.dost.gov.ph',
      'phivolcs.dost.gov.ph', 'dilg.gov.ph', 'doh.gov.ph',
      'dswd.gov.ph', 'deped.gov.ph', 'gmanetwork.com',
      'abs-cbn.com', 'inquirer.net', 'philstar.com', 'sunstar.com.ph',
    };
    final normalizedHost = uri.host.startsWith('www.')
        ? uri.host.substring(4) : uri.host;
    return hosts.contains(normalizedHost) ? uri : null;
  }
}
