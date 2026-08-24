import 'package:flutter_test/flutter_test.dart';
import 'package:tabangnow_flutter/services/native_push_service.dart';

void main() {
  test(
    'native push service singleton does not require Firebase initialization',
    () {
      expect(NativePushService.instance, isA<NativePushService>());
    },
  );

  test('native push notification id parser accepts positive ids', () {
    expect(
      notificationIdFromPushData(<String, dynamic>{'notification_id': '42'}),
      42,
    );
    expect(
      notificationIdFromPushData(<String, dynamic>{'notification_id': 7}),
      7,
    );
  });

  test('native push notification id parser rejects missing or invalid ids', () {
    expect(notificationIdFromPushData(<String, dynamic>{}), isNull);
    expect(
      notificationIdFromPushData(<String, dynamic>{'notification_id': 'bad'}),
      isNull,
    );
    expect(
      notificationIdFromPushData(<String, dynamic>{'notification_id': 0}),
      isNull,
    );
  });
}
