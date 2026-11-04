import 'package:flutter/material.dart';

import 'app_capabilities.dart';
import 'app_module.dart';
import 'app_role.dart';

class ModuleRegistry {
  const ModuleRegistry._();

  static const List<AppModuleDefinition> _modules = <AppModuleDefinition>[
    AppModuleDefinition(
      id: AppModuleId.dashboard,
      defaultLabel: 'Dashboard',
      icon: Icons.dashboard_rounded,
      websiteGlyph: '▦',
      mobileImplemented: true,
    ),
    AppModuleDefinition(
      id: AppModuleId.incidents,
      defaultLabel: 'Incidents',
      icon: Icons.description_rounded,
      websiteGlyph: '📄',
      mobileImplemented: true,
    ),
    AppModuleDefinition(
      id: AppModuleId.distressSignal,
      defaultLabel: 'Distress Signal',
      icon: Icons.warning_amber_rounded,
      websiteGlyph: '🆘',
      mobileImplemented: true,
    ),
    AppModuleDefinition(
      id: AppModuleId.tanodAlerts,
      defaultLabel: 'Tanod Alerts',
      icon: Icons.notifications_active_rounded,
      websiteGlyph: '🔔',
      mobileImplemented: true,
    ),
    AppModuleDefinition(
      id: AppModuleId.tanodRoster,
      defaultLabel: 'Tanod Roster',
      icon: Icons.groups_rounded,
      websiteGlyph: '👥',
      mobileImplemented: true,
    ),
    AppModuleDefinition(
      id: AppModuleId.tanodTasks,
      defaultLabel: 'Tanod Tasks',
      icon: Icons.assignment_rounded,
      websiteGlyph: '📋',
      mobileImplemented: true,
    ),
    AppModuleDefinition(
      id: AppModuleId.announcements,
      defaultLabel: 'Announcements',
      icon: Icons.campaign_rounded,
      websiteGlyph: '📢',
      mobileImplemented: true,
    ),
    AppModuleDefinition(
      id: AppModuleId.emergencyHotlines,
      defaultLabel: 'Emergency Hotlines',
      icon: Icons.emergency_rounded,
      websiteGlyph: '🚨',
      mobileImplemented: true,
    ),
    AppModuleDefinition(
      id: AppModuleId.residentComplaints,
      defaultLabel: 'Resident Feedback',
      icon: Icons.chat_bubble_outline_rounded,
      websiteGlyph: '💬',
      mobileImplemented: true,
    ),
    AppModuleDefinition(
      id: AppModuleId.barangayMap,
      defaultLabel: 'Map',
      icon: Icons.map_rounded,
      websiteGlyph: '🗺️',
      mobileImplemented: true,
    ),
    AppModuleDefinition(
      id: AppModuleId.reports,
      defaultLabel: 'Reports',
      icon: Icons.bar_chart_rounded,
      websiteGlyph: '📊',
      mobileImplemented: true,
    ),
    AppModuleDefinition(
      id: AppModuleId.userManagement,
      defaultLabel: 'User Management',
      icon: Icons.manage_accounts_rounded,
      websiteGlyph: '⚙️',
      mobileImplemented: true,
    ),
    AppModuleDefinition(
      id: AppModuleId.activityLogs,
      defaultLabel: 'Activity Logs',
      icon: Icons.receipt_long_rounded,
      websiteGlyph: '🧾',
      mobileImplemented: true,
    ),
    AppModuleDefinition(
      id: AppModuleId.systemBranding,
      defaultLabel: 'System Branding',
      icon: Icons.branding_watermark_rounded,
      websiteGlyph: '🛡️',
      mobileImplemented: true,
      showInNavigation: false,
    ),
  ];

  static List<AppModuleDefinition> forRole(AppRole role) {
    return _modules
        .where(
          (definition) =>
              definition.showInNavigation &&
              canAccess(role, definition.id) &&
              !(role == AppRole.tanod &&
                  definition.id == AppModuleId.distressSignal),
        )
        .toList(growable: false);
  }

  static bool canAccess(AppRole role, AppModuleId module) {
    final capabilities = AppCapabilities.forRole(role);

    switch (module) {
      case AppModuleId.dashboard:
        return capabilities.allows(AppCapability.viewDashboard);

      case AppModuleId.incidents:
        return capabilities.allows(AppCapability.viewIncidents);

      case AppModuleId.distressSignal:
        return capabilities.allows(AppCapability.manageDistressSignal);

      case AppModuleId.tanodAlerts:
        return capabilities.allows(AppCapability.viewTanodAlerts);

      case AppModuleId.tanodRoster:
        return capabilities.allows(AppCapability.viewTanodRoster);

      case AppModuleId.tanodTasks:
        return capabilities.allowsAny(const <AppCapability>{
          AppCapability.manageTanodTasks,
          AppCapability.respondToTanodTasks,
        });

      case AppModuleId.announcements:
        return capabilities.allows(AppCapability.viewAnnouncements);

      case AppModuleId.emergencyHotlines:
        return capabilities.allows(AppCapability.viewEmergencyHotlines);

      case AppModuleId.residentComplaints:
        return capabilities.allows(AppCapability.viewResidentComplaints);

      case AppModuleId.barangayMap:
        return capabilities.allows(AppCapability.viewBarangayMap);

      case AppModuleId.reports:
        return capabilities.allows(AppCapability.viewReports);

      case AppModuleId.userManagement:
        return capabilities.allows(AppCapability.manageUsers);

      case AppModuleId.activityLogs:
        return capabilities.allows(AppCapability.viewActivityLogs);

      case AppModuleId.systemBranding:
        return capabilities.allows(AppCapability.manageSystemBranding);
    }
  }
}
