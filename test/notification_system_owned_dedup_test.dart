import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabangnow_flutter/services/native_push_service.dart';

void main() {
  test('FCM system presentation prevents duplicate background alerts', () {
    expect(
      shouldRenderLocalBackgroundPush(
        const RemoteMessage(
          data: <String, dynamic>{'type': 'incident'},
          notification: RemoteNotification(title: 'Incident'),
        ),
      ),
      isFalse,
    );

    expect(
      shouldRenderLocalBackgroundPush(
        const RemoteMessage(data: <String, dynamic>{'type': 'incident'}),
      ),
      isTrue,
    );
  });
}
