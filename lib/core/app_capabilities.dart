import 'app_role.dart';

enum AppCapability {
  viewDashboard,

  viewIncidents,
  createIncident,
  updateIncident,
  assignIncident,
  escalateIncident,
  addIncidentMessage,
  deleteIncident,

  manageDistressSignal,

  viewTanodAlerts,
  manageOwnTanodAlerts,

  viewTanodRoster,
  manageTanodRoster,

  manageTanodTasks,
  respondToTanodTasks,

  viewAnnouncements,
  manageAnnouncements,

  viewEmergencyHotlines,
  manageEmergencyHotlines,

  viewResidentComplaints,
  createResidentComplaint,
  processResidentComplaint,
  deleteResidentComplaint,

  viewBarangayMap,
  manageBarangays,

  viewReports,
  manageUsers,
  viewActivityLogs,
  manageSystemBranding,
}

class AppCapabilitySet {
  const AppCapabilitySet(this._allowed);

  final Set<AppCapability> _allowed;

  bool allows(AppCapability capability) {
    return _allowed.contains(capability);
  }

  bool allowsAny(Iterable<AppCapability> capabilities) {
    for (final capability in capabilities) {
      if (allows(capability)) {
        return true;
      }
    }

    return false;
  }
}

/// Mobile presentation capabilities mirroring the current Laravel website
/// authorization model.
///
/// SECURITY NOTE:
/// This class controls Flutter visibility and affordances only.
/// Laravel Gates/Policies and record ownership checks remain authoritative.
/// Record-specific abilities (for example, whether a Tanod may update one
/// particular incident) must continue to come from the API response/policy.
class AppCapabilities {
  const AppCapabilities._();

  static AppCapabilitySet forRole(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return const AppCapabilitySet(<AppCapability>{
          AppCapability.viewDashboard,

          AppCapability.viewIncidents,
          AppCapability.createIncident,
          AppCapability.updateIncident,
          AppCapability.assignIncident,
          AppCapability.escalateIncident,
          AppCapability.addIncidentMessage,
          AppCapability.deleteIncident,

          AppCapability.manageDistressSignal,

          AppCapability.viewTanodAlerts,
          AppCapability.manageOwnTanodAlerts,

          AppCapability.viewTanodRoster,
          AppCapability.manageTanodRoster,

          AppCapability.manageTanodTasks,

          AppCapability.viewAnnouncements,
          AppCapability.manageAnnouncements,

          AppCapability.viewEmergencyHotlines,
          AppCapability.manageEmergencyHotlines,

          AppCapability.viewResidentComplaints,
          AppCapability.processResidentComplaint,
          AppCapability.deleteResidentComplaint,

          AppCapability.viewBarangayMap,
          AppCapability.manageBarangays,

          AppCapability.viewReports,
          AppCapability.manageUsers,
          AppCapability.viewActivityLogs,
          AppCapability.manageSystemBranding,
        });

      case AppRole.official:
        return const AppCapabilitySet(<AppCapability>{
          AppCapability.viewDashboard,

          AppCapability.viewIncidents,
          AppCapability.createIncident,
          AppCapability.updateIncident,
          AppCapability.escalateIncident,
          AppCapability.addIncidentMessage,

          AppCapability.manageDistressSignal,

          AppCapability.viewTanodRoster,
          AppCapability.manageTanodRoster,

          AppCapability.viewAnnouncements,

          AppCapability.viewEmergencyHotlines,
          AppCapability.manageEmergencyHotlines,

          AppCapability.viewResidentComplaints,
          AppCapability.processResidentComplaint,

          AppCapability.viewBarangayMap,
          AppCapability.manageBarangays,
        });

      case AppRole.tanod:
        return const AppCapabilitySet(<AppCapability>{
          AppCapability.viewDashboard,

          AppCapability.viewIncidents,
          AppCapability.updateIncident,
          AppCapability.addIncidentMessage,

          AppCapability.viewTanodAlerts,
          AppCapability.manageOwnTanodAlerts,

          AppCapability.respondToTanodTasks,

          AppCapability.viewAnnouncements,
          AppCapability.viewEmergencyHotlines,
        });

      case AppRole.resident:
        return const AppCapabilitySet(<AppCapability>{
          AppCapability.viewDashboard,

          AppCapability.viewIncidents,
          AppCapability.createIncident,
          AppCapability.addIncidentMessage,

          AppCapability.viewAnnouncements,
          AppCapability.viewEmergencyHotlines,

          AppCapability.viewResidentComplaints,
          AppCapability.createResidentComplaint,
        });

      case AppRole.unknown:
        return const AppCapabilitySet(<AppCapability>{});
    }
  }
}
