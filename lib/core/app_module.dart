import 'package:flutter/material.dart';

import 'app_role.dart';

enum AppModuleId {
  dashboard,
  incidents,
  distressSignal,
  tanodAlerts,
  tanodRoster,
  tanodTasks,
  announcements,
  emergencyHotlines,
  residentComplaints,
  barangayMap,
  reports,
  userManagement,
  activityLogs,
  systemBranding,
}

class AppModuleDefinition {
  const AppModuleDefinition({
    required this.id,
    required this.defaultLabel,
    required this.icon,
    required this.websiteGlyph,
    required this.mobileImplemented,
    this.showInNavigation = true,
  });

  final AppModuleId id;
  final String defaultLabel;
  final IconData icon;

  /// Website sidebar glyph/emoji. This is presentation metadata only and
  /// does not affect role access or backend authorization.
  final String websiteGlyph;

  /// Documents whether the feature currently has a connected mobile
  /// implementation. HomeScreen still verifies that a concrete route/screen
  /// mapping exists before treating it as live.
  final bool mobileImplemented;

  final bool showInNavigation;

  String labelFor(AppRole role) {
    switch (id) {
      case AppModuleId.incidents:
        switch (role) {
          case AppRole.tanod:
            return 'Assigned Incidents';
          case AppRole.resident:
            return 'Report Incident';
          default:
            return defaultLabel;
        }

      case AppModuleId.residentComplaints:
        if (role == AppRole.resident) {
          return 'Resident Feedback';
        }

        return defaultLabel;

      default:
        return defaultLabel;
    }
  }

  String websiteGlyphFor(AppRole role) {
    if (id == AppModuleId.residentComplaints && role == AppRole.resident) {
      return '📝';
    }

    return websiteGlyph;
  }
}
