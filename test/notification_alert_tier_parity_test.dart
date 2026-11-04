import 'package:flutter_test/flutter_test.dart';
import 'package:tabangnow_flutter/services/background_notification_alert_service.dart';

void main() {
  TabangNowAlertTier tier(String type, String? alertTier) {
    final notificationData = <String, dynamic>{'type': type};
    if (alertTier != null) {
      notificationData['alert_tier'] = alertTier;
    }
    return TabangNowNotificationAlert.tierFromDataForTest(notificationData);
  }

  group('Laravel / Flutter Code Red tier parity', () {
    test('all approved Code Red categories override stale server tiers', () {
      for (final type in <String>[
        'announcement',
        'calamity',
        'mobile_emergency',
        'emergency',
        'incident',
        'incident_reported',
        'incident_message',
        'incident_update',
        'incident_updated',
        'incident_status_update',
        'assigned_incident',
        'incident_assigned',
        'new_assigned_incident',
        'dispatch',
        'escalation',
        'tanod_alert',
        'tanod_task',
        'tanod_task_assigned',
        'task_assigned',
        'tanod_task_update',
        'tanod_task_response',
        'task_update',
      ]) {
        for (final sentTier in <String?>[null, 'critical', 'moderate', 'low']) {
          expect(tier(type, sentTier), TabangNowAlertTier.critical,
              reason: '$type must ring Code Red even when alert_tier=$sentTier');
        }
      }
    });

    test('routine messages and distress acknowledgements stay non-Red', () {
      for (final type in <String>[
        'user_registration',
        'resident_complaint',
        'community_problem',
        'account_deactivated',
        'mobile_emergency_acknowledged',
        'status_update',
        'resolved',
        'mobile_emergency_received',
        'mobile_emergency_resolved',
        'resident_complaint_update',
        'account_activated',
        'unknown_future_notification',
      ]) {
        expect(tier(type, 'critical'), TabangNowAlertTier.moderate,
            reason: '$type must not impersonate Code Red');
        expect(tier(type, 'moderate'), TabangNowAlertTier.moderate);
        expect(tier(type, 'low'), TabangNowAlertTier.low);
        expect(tier(type, null), TabangNowAlertTier.low);
      }
    });

    test('retired Case Management and internal types remain silent', () {
      for (final type in <String>[
        'case_created',
        'case_updated',
        'case_deleted',
        'system',
      ]) {
        expect(tier(type, 'silent'), TabangNowAlertTier.silent);
      }
    });
  });
}
