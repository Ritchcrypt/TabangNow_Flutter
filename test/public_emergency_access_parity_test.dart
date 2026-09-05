import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public auth screens retain the spinning SOS launcher', () {
    final authGate = File('lib/screens/auth_gate.dart').readAsStringSync();
    final login = File('lib/screens/login_screen.dart').readAsStringSync();
    final register = File('lib/screens/register_screen.dart').readAsStringSync();
    final sharedHeader = File(
      'lib/widgets/public_auth_branding_header.dart',
    ).readAsStringSync();

    expect(authGate, contains('SosFlipCoinButton'));
    expect(login, contains('PublicAuthBrandingHeader'));
    expect(register, contains('PublicAuthBrandingHeader'));
    expect(sharedHeader, contains('SosFlipCoinButton'));

    for (final source in <String>[
      authGate,
      login,
      register,
      sharedHeader,
    ]) {
      expect(
        source,
        isNot(contains('PublicEmergencyAccessCard')),
        reason: 'Public auth surfaces must not render the removed Emergency SOS card.',
      );
    }
  });

  test(
    'global SOS form uses Name, Mobile Number, Emergency, then location',
    () {
      final overlay = File(
        'lib/widgets/global_sos_overlay.dart',
      ).readAsStringSync();
      final service = File(
        'lib/services/mobile_sos_service.dart',
      ).readAsStringSync();

      final name = overlay.indexOf("labelText: 'Name'");
      final mobile = overlay.indexOf("labelText: 'Mobile Number'");
      final emergency = overlay.indexOf("labelText: 'What is the emergency?'");
      final location = overlay.indexOf('_LocationStatusCard(');

      expect(name, greaterThanOrEqualTo(0));
      expect(mobile, greaterThan(name));
      expect(emergency, greaterThan(mobile));
      expect(location, greaterThan(emergency));

      expect(overlay, contains('name: _nameController.text'));
      expect(service, contains('required String name'));
      expect(service, contains("'name': name.trim()"));
    },
  );

  test('SOS light semantic cards retain readable text in dark mode', () {
    final overlay = File(
      'lib/widgets/global_sos_overlay.dart',
    ).readAsStringSync();

    for (final marker in <String>[
      'Color(0xFF7C2D12)',
      'Color(0xFF065F46)',
      'Color(0xFF047857)',
      'Color(0xFF991B1B)',
      'Color(0xFFB91C1C)',
      'foregroundColor: theme.colorScheme.onSurfaceVariant',
    ]) {
      expect(
        overlay,
        contains(marker),
        reason: 'Missing SOS readability marker: $marker',
      );
    }
  });

  test('public branding fallback stays on the unified API port', () {
    final service = File(
      'lib/services/public_branding_logo_service.dart',
    ).readAsStringSync();

    expect(service, isNot(contains('127.0.0.1:8001')));
    expect(service, contains('127.0.0.1:8000'));
  });
}
