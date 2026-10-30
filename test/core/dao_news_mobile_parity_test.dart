import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabangnow_flutter/services/dao_news_service.dart';

void main() {
  test('news link allows HTTPS from a trusted publisher only', () {
    const good = DaoNewsStory(title: 'Dao, Capiz',
      url: 'https://pia.gov.ph/news/visayas/wv/sample', source: 'pia.gov.ph');
    const bad = DaoNewsStory(title: 'Fake',
      url: 'https://pia.gov.ph.evil.example/article', source: 'fake');
    const http = DaoNewsStory(title: 'HTTP',
      url: 'http://pia.gov.ph/article', source: 'pia.gov.ph');
    expect(good.safeUri, isNotNull);
    expect(bad.safeUri, isNull);
    expect(http.safeUri, isNull);
  });

  test('mobile banner keeps role-shared photo and does not touch Code Red', () {
    final banner = File('lib/widgets/shared_dashboard_welcome_banner.dart').readAsStringSync();
    expect(banner, contains('Change photo'));
    expect(banner, contains('Tap center to open'));
    expect(banner, contains('Tap edges to browse'));
    expect(banner, contains('DaoNewsManager'));
    expect(banner, isNot(contains('FLAG_INSISTENT')));
  });

  test('mobile service uses website-backed bearer API, not external feeds', () {
    final source = File('lib/services/dao_news_service.dart').readAsStringSync();
    expect(source, contains('/api/v1/dashboard/dao-news'));
    expect(source, contains('Authorization'));
    expect(source, isNot(contains('news.google.com')));
    expect(source, isNot(contains('gnews.io')));
    expect(source, isNot(contains('imageUrl')));
  });
}
