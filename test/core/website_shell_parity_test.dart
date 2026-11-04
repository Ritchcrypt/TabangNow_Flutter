import 'package:flutter_test/flutter_test.dart';

import 'package:tabangnow_flutter/core/app_module.dart';
import 'package:tabangnow_flutter/core/app_role.dart';
import 'package:tabangnow_flutter/core/module_registry.dart';

AppModuleDefinition moduleFor(AppRole role, AppModuleId id) {
  return ModuleRegistry.forRole(role).firstWhere((module) => module.id == id);
}

void main() {
  group('website sidebar parity metadata', () {
    test('admin website glyphs match established sidebar', () {
      expect(moduleFor(AppRole.admin, AppModuleId.dashboard).websiteGlyph, '▦');
      expect(
        moduleFor(AppRole.admin, AppModuleId.incidents).websiteGlyph,
        '📄',
      );
      expect(
        moduleFor(AppRole.admin, AppModuleId.tanodAlerts).websiteGlyph,
        '🔔',
      );
      expect(
        moduleFor(AppRole.admin, AppModuleId.tanodRoster).websiteGlyph,
        '👥',
      );
      expect(
        moduleFor(AppRole.admin, AppModuleId.tanodTasks).websiteGlyph,
        '📋',
      );
      expect(
        moduleFor(AppRole.admin, AppModuleId.announcements).websiteGlyph,
        '📢',
      );
      expect(
        moduleFor(AppRole.admin, AppModuleId.emergencyHotlines).websiteGlyph,
        '🚨',
      );
      expect(
        moduleFor(AppRole.admin, AppModuleId.residentComplaints).websiteGlyph,
        '💬',
      );
      expect(moduleFor(AppRole.admin, AppModuleId.reports).websiteGlyph, '📊');
      expect(
        moduleFor(AppRole.admin, AppModuleId.activityLogs).websiteGlyph,
        '🧾',
      );
    });

    test('resident feedback entry uses website form glyph', () {
      final complaint = moduleFor(
        AppRole.resident,
        AppModuleId.residentComplaints,
      );

      expect(complaint.labelFor(AppRole.resident), 'Resident Feedback');
      expect(complaint.websiteGlyphFor(AppRole.resident), '📝');
    });
  });
}
