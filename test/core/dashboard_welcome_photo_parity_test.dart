import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile dashboard uses the shared photo with admin-only direct picker', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    final banner = File('lib/widgets/shared_dashboard_welcome_banner.dart').readAsStringSync();
    final service = File('lib/services/dashboard_welcome_photo_service.dart').readAsStringSync();
    expect(home, contains('SharedDashboardWelcomeBanner('));
    expect(home, contains("isAdmin: _role == 'admin'"));
    expect(banner, contains('if (widget.isAdmin)'));
    expect(banner, contains('FilePicker.platform.pickFiles('));
    expect(banner, contains('await _service.upload(file)'));
    expect(banner, contains('Duration(seconds: 20)'));
    expect(banner, isNot(contains('AlertDialog(')));
    expect(service, contains('Authorization'));
    expect(service, contains('/api/v1/dashboard/welcome-photo'));
    // Preserve existing FCM handling; no notification files are part of this patch.
  });
}
