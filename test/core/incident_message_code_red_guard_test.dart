import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('incident messages retain the established Code Red routing', () {
    final source = File(
      'lib/services/background_notification_alert_service.dart',
    ).readAsStringSync();

    final begin = source.indexOf('const codeRedTypes = <String>{');
    expect(begin, greaterThanOrEqualTo(0));
    final end = source.indexOf('};', begin);
    expect(end, greaterThan(begin));
    final types = source.substring(begin, end);

    expect(types, contains("'incident_message',"));
    expect(
      source,
      contains("static const String channelId = 'tabangnow_notifications_v4';"),
    );
    expect(
      File('android/app/src/main/res/raw/tabangnow_notification_v4.mp3')
          .existsSync(),
      isTrue,
    );
  });
}
