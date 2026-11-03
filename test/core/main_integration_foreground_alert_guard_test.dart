import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('foreground FCM keeps on-device incident alert playback', () {
    final source = File('lib/services/native_push_service.dart')
        .readAsStringSync();
    expect(
      RegExp(
        r'FirebaseMessaging\.onMessage\.listen\(\(message\) async \{'
        r'[\s\S]*?TabangNowNotificationAlert\.showFromData\(message\.data\)',
      ).hasMatch(source),
      isTrue,
      reason: 'Removing the foreground audio call regresses Code Red alerts.',
    );
  });

  test('Firebase project and notification resources stay aligned', () {
    final config = jsonDecode(
      File('android/app/google-services.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final project = config['project_info'] as Map<String, dynamic>;
    expect(project['project_id'], 'tabangnow-mobile-2026');
    expect(
      File('lib/firebase_options.dart').readAsStringSync(),
      contains('tabangnow-mobile-2026'),
    );
    for (final name in <String>[
      'tabangnow_notification_v4.mp3',
      'tabangnow_moderate_v1.mp3',
      'tabangnow_low_v1.mp3',
    ]) {
      expect(File('android/app/src/main/res/raw/$name').existsSync(), isTrue);
    }
  });

  test('removed Case Management API does not return on mobile', () {
    expect(File('lib/services/case_management_service.dart').existsSync(), isFalse);
    expect(File('lib/screens/account_mfa_screen.dart').existsSync(), isTrue);
  });
}
