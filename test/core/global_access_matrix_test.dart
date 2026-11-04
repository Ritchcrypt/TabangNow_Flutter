import 'package:flutter_test/flutter_test.dart';

import 'package:tabangnow_flutter/core/app_capabilities.dart';
import 'package:tabangnow_flutter/core/app_module.dart';
import 'package:tabangnow_flutter/core/app_role.dart';
import 'package:tabangnow_flutter/core/module_registry.dart';

Set<AppModuleId> visible(AppRole role) {
  return ModuleRegistry.forRole(role).map((module) => module.id).toSet();
}

void main() {
  group('TabangNow global role access matrix', () {
    test('admin navigation stays administrative', () {
      final modules = visible(AppRole.admin);

      expect(
        modules,
        containsAll(<AppModuleId>{
          AppModuleId.dashboard,
          AppModuleId.incidents,
          AppModuleId.tanodAlerts,
          AppModuleId.tanodRoster,
          AppModuleId.tanodTasks,
          AppModuleId.announcements,
          AppModuleId.emergencyHotlines,
          AppModuleId.residentComplaints,
          AppModuleId.barangayMap,
          AppModuleId.reports,
          AppModuleId.userManagement,
          AppModuleId.activityLogs,
        }),
      );
    });

    test('official does not inherit admin/tanod-only modules', () {
      final modules = visible(AppRole.official);

      expect(modules, contains(AppModuleId.dashboard));
      expect(modules, contains(AppModuleId.incidents));
      expect(modules, contains(AppModuleId.tanodRoster));
      expect(modules, contains(AppModuleId.announcements));
      expect(modules, contains(AppModuleId.emergencyHotlines));
      expect(modules, contains(AppModuleId.residentComplaints));
      expect(modules, contains(AppModuleId.barangayMap));

      expect(modules, isNot(contains(AppModuleId.tanodAlerts)));
      expect(modules, isNot(contains(AppModuleId.tanodTasks)));
      expect(modules, isNot(contains(AppModuleId.reports)));
      expect(modules, isNot(contains(AppModuleId.userManagement)));
      expect(modules, isNot(contains(AppModuleId.activityLogs)));
    });

    test('tanod sees operational modules only', () {
      final modules = visible(AppRole.tanod);

      expect(
        modules,
        containsAll(<AppModuleId>{
          AppModuleId.dashboard,
          AppModuleId.tanodAlerts,
          AppModuleId.tanodTasks,
          AppModuleId.incidents,
          AppModuleId.announcements,
          AppModuleId.emergencyHotlines,
        }),
      );

      expect(modules, isNot(contains(AppModuleId.tanodRoster)));
      expect(modules, isNot(contains(AppModuleId.residentComplaints)));
      expect(modules, isNot(contains(AppModuleId.distressSignal)));
      expect(modules, isNot(contains(AppModuleId.barangayMap)));
      expect(modules, isNot(contains(AppModuleId.userManagement)));
    });

    test('resident stays resident-scoped', () {
      final modules = visible(AppRole.resident);

      expect(
        modules,
        containsAll(<AppModuleId>{
          AppModuleId.dashboard,
          AppModuleId.incidents,
          AppModuleId.residentComplaints,
          AppModuleId.announcements,
          AppModuleId.emergencyHotlines,
        }),
      );

      expect(modules, isNot(contains(AppModuleId.tanodAlerts)));
      expect(modules, isNot(contains(AppModuleId.tanodRoster)));
      expect(modules, isNot(contains(AppModuleId.tanodTasks)));
      expect(modules, isNot(contains(AppModuleId.barangayMap)));
      expect(modules, isNot(contains(AppModuleId.reports)));
      expect(modules, isNot(contains(AppModuleId.userManagement)));
      expect(modules, isNot(contains(AppModuleId.activityLogs)));
    });

    test('incident action limitations mirror website policy', () {
      final admin = AppCapabilities.forRole(AppRole.admin);
      final official = AppCapabilities.forRole(AppRole.official);
      final tanod = AppCapabilities.forRole(AppRole.tanod);
      final resident = AppCapabilities.forRole(AppRole.resident);

      expect(admin.allows(AppCapability.assignIncident), isTrue);
      expect(admin.allows(AppCapability.deleteIncident), isTrue);

      expect(official.allows(AppCapability.assignIncident), isFalse);
      expect(official.allows(AppCapability.deleteIncident), isFalse);
      expect(official.allows(AppCapability.escalateIncident), isTrue);

      expect(tanod.allows(AppCapability.createIncident), isFalse);
      expect(tanod.allows(AppCapability.updateIncident), isTrue);
      expect(tanod.allows(AppCapability.assignIncident), isFalse);

      expect(resident.allows(AppCapability.createIncident), isTrue);
      expect(resident.allows(AppCapability.updateIncident), isFalse);
      expect(resident.allows(AppCapability.deleteIncident), isFalse);
    });

    test('branding management remains admin-only', () {
      expect(
        ModuleRegistry.canAccess(AppRole.admin, AppModuleId.systemBranding),
        isTrue,
      );

      for (final role in <AppRole>[
        AppRole.official,
        AppRole.tanod,
        AppRole.resident,
        AppRole.unknown,
      ]) {
        expect(
          ModuleRegistry.canAccess(role, AppModuleId.systemBranding),
          isFalse,
        );
      }
    });

    test('unknown roles receive no modules', () {
      expect(ModuleRegistry.forRole(AppRole.unknown), isEmpty);
    });
  });
}
