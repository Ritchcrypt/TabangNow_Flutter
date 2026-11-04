import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only Code Red notification channel has vibration enabled', () {
    final source = File(
      'lib/services/background_notification_alert_service.dart',
    ).readAsStringSync();

    // Existing user-configurable Code Red v4 alarm must remain untouched.
    expect(source.contains("channelId = 'tabangnow_notifications_v4'"), isTrue);
    expect(source.contains("'tabangnow_notification_v4'"), isTrue);
    expect(source.contains('vibrationPattern: _criticalVibrationPattern'), isTrue);

    // Android channels cannot change vibration once created, so we route
    // audible Moderate/Low notifications to new IDs while retaining the
    // original sound resources. All non-Code-Red paths are non-vibrating.
    expect(source.contains("moderateChannelId = 'tabangnow_moderate_v2'"), isTrue);
    expect(source.contains("lowChannelId = 'tabangnow_low_v2'"), isTrue);
    expect(source.contains("'tabangnow_moderate_v1'"), isTrue);
    expect(source.contains("'tabangnow_low_v1'"), isTrue);
    expect(source.contains('vibrationPattern: _moderateVibrationPattern'), isFalse);
    expect(source.contains('vibrationPattern: _lowVibrationPattern'), isFalse);

    final moderateDefinition = source.substring(
      source.indexOf('moderateChannelId,'),
      source.indexOf('lowChannelId,'),
    );
    expect(moderateDefinition.contains('enableVibration: false'), isTrue);

    final lowDefinition = source.substring(
      source.indexOf('lowChannelId,'),
      source.indexOf('silentChannelId,'),
    );
    expect(lowDefinition.contains('enableVibration: false'), isTrue);

    final moderateNotification = source.substring(
      source.indexOf('static Future<void> _showModerate'),
      source.indexOf('static Future<void> _showLow'),
    );
    final lowNotification = source.substring(
      source.indexOf('static Future<void> _showLow'),
      source.indexOf('static Future<void> _showSilent'),
    );
    expect(moderateNotification.contains('enableVibration: false'), isTrue);
    expect(lowNotification.contains('enableVibration: false'), isTrue);
    expect(moderateNotification.contains('playSound: true'), isTrue);
    expect(lowNotification.contains('playSound: true'), isTrue);
  });
}
