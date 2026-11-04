import 'package:flutter_test/flutter_test.dart';
import 'package:tabangnow_flutter/widgets/dao_news_manager.dart';

void main() {
  group('news audit display labels', () {
    final news = <String, dynamic>{
      'url': 'https://www.pna.gov.ph/article/capiz-health-update',
      'topic': 'Health and services',
      'link_status': 'ok',
    };

    test('shows friendly actions and article context without IDs', () {
      final event = <String, dynamic>{
        'action': 'edited',
        'actor_id': 32,
        'link_id': '989245cf-f4be-465f-8882-d010e5266165',
        'at': '2026-10-30T06:45:00+00:00',
        'before': null,
        'after': news,
      };
      expect(DaoNewsAuditPresentation.title(event), 'Article updated');
      expect(DaoNewsAuditPresentation.article(event),
          'pna.gov.ph · capiz health update');
      expect(DaoNewsAuditPresentation.date(event), contains('Oct 30, 2026'));
      expect(DaoNewsAuditPresentation.article(event), isNot(contains('989245cf')));
    });

    test('link-health status is understandable', () {
      expect(
        DaoNewsAuditPresentation.title(<String, dynamic>{
          'action': 'link_checked',
          'after': news,
        }),
        'Link checked: available',
      );
    });

    test('removed entries can still identify the original article', () {
      expect(
        DaoNewsAuditPresentation.article(<String, dynamic>{
          'action': 'removed',
          'before': news,
          'after': null,
        }),
        'pna.gov.ph · capiz health update',
      );
    });

    test('unavailable details fail gracefully', () {
      expect(DaoNewsAuditPresentation.date(<String, dynamic>{'at': 'bad'}),
          'Date unavailable');
      expect(DaoNewsAuditPresentation.article(<String, dynamic>{}),
          'Article details unavailable');
    });
  });
}
