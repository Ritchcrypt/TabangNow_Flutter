import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabangnow_flutter/services/native_push_service.dart';

void main() {
  test('fresh install has a bounded retry policy', () {
    expect(NativePushService.registrationRetryDelay(0), const Duration(seconds: 5));
    expect(NativePushService.registrationRetryDelay(1), const Duration(seconds: 20));
    expect(NativePushService.registrationRetryDelay(2), const Duration(minutes: 1));
    expect(NativePushService.registrationRetryDelay(3), const Duration(minutes: 3));
    expect(NativePushService.registrationRetryDelay(4), isNull);
  });

  test('notification permission is not allowed to skip device token registration', () {
    final source = File('lib/services/native_push_service.dart').readAsStringSync();
    expect(source.contains('continuing server token registration.'), isTrue);
    expect(source.contains('await _registerToken(token, authService);'), isTrue);
    expect(source.contains('throw StateError(\'No authenticated session for push registration.\');'), isTrue);
    expect(source.contains('Retry in '), isTrue);
    expect(source.contains('unawaited(syncForAuthenticatedUser(authService))'), isTrue);
  });
}
