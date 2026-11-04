import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mobile barangay selector contract', () {
    test('signup stays on an explicit light public-auth surface', () {
      final screen = File(
        'lib/screens/register_screen.dart',
      ).readAsStringSync();

      expect(screen.contains('_registrationLightTheme'), isTrue);

      expect(screen.contains('Brightness.light'), isTrue);

      expect(screen.contains('TABANGNOW_SIGNUP_BRANDING_LIGHT'), isTrue);

      expect(screen.contains('Barangay of residence'), isTrue);
    });

    test('signup submits the selected barangay id', () {
      final screen = File(
        'lib/screens/register_screen.dart',
      ).readAsStringSync();

      final service = File(
        'lib/services/registration_service.dart',
      ).readAsStringSync();

      expect(screen.contains('barangayId: _selectedBarangayId!'), isTrue);

      expect(service.contains('/api/v1/auth/barangays'), isTrue);

      expect(service.contains("'barangay_id': ?barangayId"), isTrue);
    });

    test('shared profile exposes residential barangay selector', () {
      final screen = File(
        'lib/screens/current_account_profile_screen.dart',
      ).readAsStringSync();

      final service = File(
        'lib/services/profile_service.dart',
      ).readAsStringSync();

      expect(screen.contains('Barangay of Residence'), isTrue);

      expect(screen.contains('_selectedBarangayId'), isTrue);

      expect(service.contains("'barangay_id': barangayId.toString()"), isTrue);
    });
  });
}
