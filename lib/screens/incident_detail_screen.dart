import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/tabangnow_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../services/auth_service.dart';
import '../services/case_management_service.dart';
import '../services/incident_service.dart';
import 'case_form_screen.dart';

class IncidentDetailScreen extends StatefulWidget {
  const IncidentDetailScreen({
    super.key,
    required this.incidentService,
    required this.incidentId,
    required this.user,
  });

  final IncidentService incidentService;
  final int incidentId;
  final Map<String, dynamic> user;

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  final TextEditingController _escalationReasonController =
      TextEditingController();

  bool _loading = true;
  bool _actionBusy = false;
  String? _error;

  Map<String, dynamic> _incident = <String, dynamic>{};
  Map<String, dynamic> _permissions = <String, dynamic>{};
  Map<String, dynamic> _options = <String, dynamic>{};

  int? _selectedStatusId;
  int? _selectedResponderId;
  bool _assignmentChanged = false;
  String? _selectedAgency;

  String get _role =>
      widget.user['role']?.toString().trim().toLowerCase() ?? '';

  bool _can(String permission) => _permissions[permission] == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _escalationReasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await widget.incidentService.incident(widget.incidentId);

      final incident = _map(response['data']);
      final permissions = _map(response['permissions']);
      final options = _map(response['options']);

      final statuses = _uniqueByIntId(_mapList(options['statuses']));
      final agencies = _uniqueByStringValue(
        _mapList(options['agencies']),
        key: 'value',
      );
      final responders = _uniqueByIntId(_mapList(options['responders']));

      options['statuses'] = statuses;
      options['agencies'] = agencies;
      options['responders'] = responders;

      final currentStatusId = _toInt(incident['status_id']);

      final validStatusIds = statuses
          .map((status) => _toInt(status['id']))
          .whereType<int>()
          .toSet();

      final safeStatusId =
          currentStatusId != null && validStatusIds.contains(currentStatusId)
          ? currentStatusId
          : (statuses.isNotEmpty ? _toInt(statuses.first['id']) : null);

      final assignedTanod = _map(incident['assigned_tanod']);
      final currentResponderId = _toInt(assignedTanod['id']);
      final validResponderIds = responders
          .map((responder) => _toInt(responder['id']))
          .whereType<int>()
          .toSet();
      final safeResponderId =
          currentResponderId != null &&
              validResponderIds.contains(currentResponderId)
          ? currentResponderId
          : null;

      final validAgencyValues = agencies
          .map((agency) => agency['value']?.toString().trim())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet();

      final firstAgency = agencies.isNotEmpty
          ? agencies.first['value']?.toString().trim()
          : null;

      if (!mounted) {
        return;
      }

      setState(() {
        _incident = incident;
        _permissions = permissions;
        _options = options;

        _selectedStatusId = safeStatusId;
        _selectedResponderId = safeResponderId;
        _assignmentChanged = false;

        _selectedAgency =
            firstAgency != null && validAgencyValues.contains(firstAgency)
            ? firstAgency
            : null;

        _loading = false;
        _error = null;
      });
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = exception.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Unable to load incident details.';
      });
    }
  }

  Future<void> _saveUpdate() async {
    final statusId = _selectedStatusId;

    if (statusId == null || _actionBusy) {
      _showMessage('Select a status first.');
      return;
    }

    await _runAction(
      action: () => widget.incidentService.updateStatus(
        incidentId: widget.incidentId,
        statusId: statusId,
        includeAssignedTo: _can('can_assign') && _assignmentChanged,
        assignedTo: _selectedResponderId,
      ),
      successMessage: 'Incident updated successfully.',
    );
  }

  Future<void> _escalate() async {
    final agency = _selectedAgency?.trim() ?? '';

    if (agency.isEmpty || _actionBusy) {
      _showMessage('Select an escalation agency.');
      return;
    }

    await _runAction(
      action: () => widget.incidentService.escalateIncident(
        incidentId: widget.incidentId,
        agency: agency,
        reason: _escalationReasonController.text,
      ),
      successMessage: 'Incident escalated successfully.',
      clearAfter: () {
        _escalationReasonController.clear();
      },
    );
  }

  Future<void> _createRelatedCase() async {
    if (_role != 'admin' || _actionBusy) {
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      final service = CaseManagementService(
        authService: widget.incidentService.authService,
      );

      final response = await service.index(page: 1);
      final options = _map(response['options']);
      final caseTypes = _mapList(options['case_types']);
      final caseStatuses = _mapList(options['case_statuses']);
      final incidents = _mapList(options['incidents']);

      final hasCurrentIncident = incidents.any(
        (item) => _toInt(item['id']) == widget.incidentId,
      );

      if (!hasCurrentIncident) {
        final title =
            _incident['title']?.toString().trim() ?? 'Untitled Incident';

        incidents.insert(0, <String, dynamic>{
          'id': widget.incidentId,
          'title': title,
          'label': 'Incident #${widget.incidentId} — $title',
        });
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _actionBusy = false;
      });

      final message = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => CaseFormScreen(
            service: service,
            caseTypes: caseTypes,
            caseStatuses: caseStatuses,
            incidents: incidents,
            initialIncidentId: widget.incidentId,
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      if (message != null && message.trim().isNotEmpty) {
        _showMessage(message);
        await _load();
      }
    } on AuthException catch (exception) {
      if (mounted) {
        _showMessage(exception.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to open the Create Case form.');
      }
    } finally {
      if (mounted && _actionBusy) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _runAction({
    required Future<Map<String, dynamic>> Function() action,
    required String successMessage,
    VoidCallback? clearAfter,
  }) async {
    if (_actionBusy) {
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      await action();

      clearAfter?.call();

      if (!mounted) {
        return;
      }

      _showMessage(successMessage);
      await _load();
    } on AuthException catch (exception) {
      if (mounted) {
        _showMessage(exception.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('The incident action could not be completed.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _openEvidence(Map<String, dynamic> evidence) async {
    final evidenceId = _toInt(evidence['id']);

    if (evidenceId == null) {
      _showMessage('Evidence record is unavailable.');
      return;
    }

    try {
      final bytes = await widget.incidentService.evidenceBytes(
        incidentId: widget.incidentId,
        evidenceId: evidenceId,
      );

      final mimeType = evidence['mime_type']?.toString().toLowerCase() ?? '';
      final fileName = _safeFileName(
        evidence['file_name']?.toString() ?? 'evidence_$evidenceId',
      );

      if (!mounted) {
        return;
      }

      if (mimeType.startsWith('image/')) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => _ImageEvidenceScreen(title: fileName, bytes: bytes),
          ),
        );
        return;
      }

      final temporaryDirectory = await getTemporaryDirectory();
      final file = File('${temporaryDirectory.path}/$fileName');

      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path);

      if (result.type != ResultType.done && mounted) {
        _showMessage(
          result.message.isNotEmpty
              ? result.message
              : 'No compatible app could open this file.',
        );
      }
    } on AuthException catch (exception) {
      if (mounted) {
        _showMessage(exception.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to open the evidence file.');
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabangNowTheme.of(context).pageBackground,
      appBar: AppBar(
        backgroundColor: TabangNowTheme.of(context).surface,
        surfaceTintColor: TabangNowTheme.of(context).surface,
        title: const Text('Incident Details'),
      ),
      body: Column(
        children: <Widget>[
          if (_actionBusy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const SizedBox(height: 90),
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Color(0xFFB91C1C),
          ),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ),
        ],
      );
    }

    final incident = _incident;
    final reporter = _map(incident['reporter']);
    final location = _map(incident['location']);
    final evidence = _mapList(incident['evidence']);
    final histories = _mapList(incident['status_history']);
    final relatedCases = _mapList(incident['related_cases']);

    final latitude = _toDouble(location['latitude']);
    final longitude = _toDouble(location['longitude']);

    final point = latitude != null && longitude != null
        ? LatLng(latitude, longitude)
        : null;

    final reported = _parseDate(
      incident['reported_at'] ??
          incident['incident_datetime'] ??
          incident['created_at'],
    );

    final updated = _parseDate(incident['updated_at']);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: <Widget>[
        _HeaderCard(
          title: incident['title']?.toString() ?? 'Untitled Incident',
          subtitle:
              'Detailed incident report information, reporter '
              'details, location, evidence, and status history.',
        ),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Incident Summary',
          subtitle: 'Core details submitted for this incident report.',
          child: Column(
            children: <Widget>[
              _InfoGrid(
                items: <_InfoItem>[
                  _InfoItem(
                    label: 'Incident Type',
                    value: incident['category']?.toString() ?? 'Uncategorized',
                  ),
                  _InfoItem(
                    label: 'Current Status',
                    value: incident['status']?.toString() ?? 'Pending',
                    badge: _BadgeKind.status,
                  ),
                  _InfoItem(
                    label: 'Severity',
                    value:
                        incident['severity_label']?.toString() ??
                        incident['priority']?.toString() ??
                        'Low',
                    badge: _BadgeKind.severity,
                    rawBadgeValue: incident['priority']?.toString(),
                  ),
                  _InfoItem(
                    label: 'Date Reported',
                    value: reported == null ? '—' : _formatLongDate(reported),
                  ),
                  _InfoItem(
                    label: 'Time Reported',
                    value: reported == null ? '—' : _formatTime(reported),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Description',
          child: Text(
            incident['description']?.toString() ?? 'No description provided.',
            style: TextStyle(
              color: TabangNowTheme.of(context).textSoft,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Location Details',
          subtitle: 'Barangay and exact location information.',
          child: Column(
            children: <Widget>[
              _InfoGrid(
                items: <_InfoItem>[
                  _InfoItem(
                    label: 'Barangay',
                    value:
                        location['barangay']?.toString() ??
                        incident['barangay']?.toString() ??
                        '—',
                  ),
                  _InfoItem(
                    label: 'Coordinates',
                    value: point == null
                        ? 'Not provided'
                        : '${point.latitude.toStringAsFixed(7)}, '
                              '${point.longitude.toStringAsFixed(7)}',
                  ),
                  _InfoItem(
                    label: 'Exact Address / Landmark',
                    value:
                        location['address']?.toString() ??
                        incident['location_address']?.toString() ??
                        'No exact location provided',
                  ),
                ],
              ),
              if (_role == 'admin' && point != null) ...<Widget>[
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => _FullMapPreviewScreen(
                            point: point,
                            title:
                                incident['title']?.toString() ??
                                'Incident Location',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open in Barangay Map Preview'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _IncidentMap(point: point),
              if (point == null) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFCE8),
                    border: Border.all(color: const Color(0xFFFEF08A)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'No coordinates saved for this incident yet.',
                    style: TextStyle(
                      color: Color(0xFFA16207),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Evidence / Attachments',
          subtitle: 'Uploaded photos, documents, or supporting files.',
          child: evidence.isEmpty
              ? const _EmptyPanel(
                  icon: Icons.attach_file_rounded,
                  title: 'No evidence uploaded',
                  message: 'This incident report has no attached files.',
                )
              : Column(
                  children: evidence
                      .map(
                        (item) => _EvidenceCard(
                          incidentService: widget.incidentService,
                          incidentId: widget.incidentId,
                          evidence: item,
                          onOpen: () => _openEvidence(item),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Reporter Information',
          child: _InfoGrid(
            items: <_InfoItem>[
              _InfoItem(
                label: 'Name',
                value: reporter['name']?.toString() ?? 'Unknown Reporter',
              ),
              _InfoItem(
                label: 'Contact Number',
                value: reporter['contact_number']?.toString() ?? '—',
              ),
              _InfoItem(
                label: 'Email',
                value: reporter['email']?.toString() ?? '—',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Record Info',
          child: _InfoGrid(
            items: <_InfoItem>[
              _InfoItem(
                label: 'Incident ID',
                value: '#${incident['id'] ?? '—'}',
              ),
              _InfoItem(
                label: 'Last Updated',
                value: updated == null
                    ? '—'
                    : '${_formatLongDate(updated)} '
                          '${_formatTime(updated)}',
              ),
            ],
          ),
        ),
        if (_role == 'admin') ...<Widget>[
          const SizedBox(height: 16),
          _RelatedCasesSection(
            relatedCases: relatedCases,
            onCreateCase: relatedCases.isEmpty && !_actionBusy
                ? _createRelatedCase
                : null,
          ),
        ],
        if (_can('can_update')) ...<Widget>[
          const SizedBox(height: 16),
          _buildUpdateIncidentSection(),
        ],
        if (_can('can_escalate')) ...<Widget>[
          const SizedBox(height: 16),
          _buildEscalationSection(),
        ],
        const SizedBox(height: 16),
        _StatusHistorySection(histories: histories),
      ],
    );
  }

  Widget _buildUpdateIncidentSection() {
    final statuses = _uniqueByIntId(_mapList(_options['statuses']));
    final responders = _uniqueByIntId(_mapList(_options['responders']));

    final statusIds = statuses
        .map((status) => _toInt(status['id']))
        .whereType<int>()
        .toSet();

    final safeSelectedStatusId =
        _selectedStatusId != null && statusIds.contains(_selectedStatusId)
        ? _selectedStatusId
        : (statuses.isNotEmpty ? _toInt(statuses.first['id']) : null);

    final responderIds = responders
        .map((responder) => _toInt(responder['id']))
        .whereType<int>()
        .toSet();

    final safeSelectedResponderId =
        _selectedResponderId != null &&
            responderIds.contains(_selectedResponderId)
        ? _selectedResponderId
        : null;

    return _DetailSection(
      title: 'Update Incident',
      subtitle: _can('can_assign')
          ? 'Change the current status and assigned responder for this incident.'
          : 'Change the current status for this incident.',
      child: Column(
        children: <Widget>[
          DropdownButtonFormField<int>(
            key: ValueKey<String>(
              'incident-status-${widget.incidentId}-$safeSelectedStatusId-${statuses.length}',
            ),
            initialValue: safeSelectedStatusId,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: statuses
                .map((status) {
                  final id = _toInt(status['id']);

                  if (id == null) {
                    return null;
                  }

                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text(status['name']?.toString() ?? 'Status'),
                  );
                })
                .whereType<DropdownMenuItem<int>>()
                .toList(),
            onChanged: _actionBusy
                ? null
                : (value) {
                    setState(() {
                      _selectedStatusId = value;
                    });
                  },
          ),
          if (_can('can_assign')) ...<Widget>[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey<String>(
                'incident-responder-${widget.incidentId}-${safeSelectedResponderId ?? -1}-${responders.length}',
              ),
              initialValue: safeSelectedResponderId ?? -1,
              decoration: const InputDecoration(
                labelText: 'Assigned Responder',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<int>>[
                const DropdownMenuItem<int>(
                  value: -1,
                  child: Text('Unassigned'),
                ),
                ...responders
                    .map((responder) {
                      final id = _toInt(responder['id']);

                      if (id == null) {
                        return null;
                      }

                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(
                          responder['name']?.toString() ?? 'Tanod #$id',
                        ),
                      );
                    })
                    .whereType<DropdownMenuItem<int>>(),
              ],
              onChanged: _actionBusy
                  ? null
                  : (value) {
                      setState(() {
                        _selectedResponderId =
                            value == null || value < 1 ? null : value;
                        _assignmentChanged = true;
                      });
                    },
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _actionBusy ? null : _saveUpdate,
              child: const Text('Save Update'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscalationSection() {
    final agencies = _uniqueByStringValue(
      _mapList(_options['agencies']),
      key: 'value',
    );

    final agencyValues = agencies
        .map((agency) => agency['value']?.toString().trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();

    final safeSelectedAgency =
        _selectedAgency != null && agencyValues.contains(_selectedAgency)
        ? _selectedAgency
        : (agencies.isNotEmpty
              ? agencies.first['value']?.toString().trim()
              : null);

    return _DetailSection(
      title: 'Escalate Incident',
      subtitle:
          'Forward this incident to a higher-response agency '
          'when barangay response is not enough.',
      child: Column(
        children: <Widget>[
          DropdownButtonFormField<String>(
            key: ValueKey<String>(
              'incident-agency-${widget.incidentId}-$safeSelectedAgency-${agencies.length}',
            ),
            initialValue: safeSelectedAgency,
            decoration: const InputDecoration(
              labelText: 'Agency',
              border: OutlineInputBorder(),
            ),
            items: agencies
                .map((agency) {
                  final value = agency['value']?.toString().trim();

                  if (value == null || value.isEmpty) {
                    return null;
                  }

                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(agency['label']?.toString() ?? value),
                  );
                })
                .whereType<DropdownMenuItem<String>>()
                .toList(),
            onChanged: _actionBusy
                ? null
                : (value) {
                    setState(() {
                      _selectedAgency = value;
                    });
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _escalationReasonController,
            enabled: !_actionBusy,
            maxLength: 3000,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Escalation Reason',
              hintText: 'Explain why this incident needs escalation...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
              ),
              onPressed: _actionBusy ? null : _escalate,
              child: const Text('Escalate Incident'),
            ),
          ),
        ],
      ),
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  static List<Map<String, dynamic>> _uniqueByIntId(
    List<Map<String, dynamic>> items,
  ) {
    final seen = <int>{};
    final unique = <Map<String, dynamic>>[];

    for (final item in items) {
      final id = _toInt(item['id']);

      if (id == null || !seen.add(id)) {
        continue;
      }

      unique.add(item);
    }

    return unique;
  }

  static List<Map<String, dynamic>> _uniqueByStringValue(
    List<Map<String, dynamic>> items, {
    required String key,
  }) {
    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];

    for (final item in items) {
      final value = item[key]?.toString().trim();

      if (value == null || value.isEmpty || !seen.add(value)) {
        continue;
      }

      unique.add(item);
    }

    return unique;
  }

  static int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static double? _toDouble(Object? value) {
    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: TabangNowTheme.of(context).textMain,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: TextStyle(
              color: TabangNowTheme.of(context).textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: TabangNowTheme.of(context).textMain,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: TabangNowTheme.of(context).textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

enum _BadgeKind { status, severity }

class _InfoItem {
  const _InfoItem({
    required this.label,
    required this.value,
    this.badge,
    this.rawBadgeValue,
  });

  final String label;
  final String value;
  final _BadgeKind? badge;
  final String? rawBadgeValue;
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 132,
                    child: Text(
                      item.label.toUpperCase(),
                      style: TextStyle(
                        color: TabangNowTheme.of(context).textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ),
                  Expanded(
                    child: item.badge == null
                        ? Text(
                            item.value,
                            style: TextStyle(
                              color: TabangNowTheme.of(context).textMain,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          )
                        : _IncidentBadge(
                            value: item.value,
                            kind: item.badge!,
                            rawValue: item.rawBadgeValue,
                          ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _IncidentBadge extends StatelessWidget {
  const _IncidentBadge({
    required this.value,
    required this.kind,
    this.rawValue,
  });

  final String value;
  final _BadgeKind kind;
  final String? rawValue;

  @override
  Widget build(BuildContext context) {
    final normalized = (rawValue ?? value).trim().toLowerCase();

    final (background, foreground, border) = kind == _BadgeKind.severity
        ? switch (normalized) {
            'critical' || 'emergency' => (
              const Color(0xFFFEE2E2),
              const Color(0xFFB91C1C),
              const Color(0xFFFECACA),
            ),
            'high' => (
              const Color(0xFFFFEDD5),
              const Color(0xFFC2410C),
              const Color(0xFFFED7AA),
            ),
            'moderate' || 'medium' => (
              const Color(0xFFFEF9C3),
              const Color(0xFFA16207),
              const Color(0xFFFEF08A),
            ),
            'low' => (
              const Color(0xFFDCFCE7),
              const Color(0xFF15803D),
              const Color(0xFFBBF7D0),
            ),
            _ => (
              TabangNowTheme.of(context).surfaceSoft,
              TabangNowTheme.of(context).textSoft,
              TabangNowTheme.of(context).border,
            ),
          }
        : switch (normalized) {
            'pending' || 'reported' => (
              const Color(0xFFFEF9C3),
              const Color(0xFFA16207),
              const Color(0xFFFEF08A),
            ),
            'verified' || 'validated' => (
              const Color(0xFFDBEAFE),
              const Color(0xFF1D4ED8),
              const Color(0xFFBFDBFE),
            ),
            'responding' || 'dispatched' || 'in progress' || 'in_progress' => (
              const Color(0xFFE0E7FF),
              const Color(0xFF4338CA),
              const Color(0xFFC7D2FE),
            ),
            'resolved' || 'completed' || 'closed' => (
              const Color(0xFFDCFCE7),
              const Color(0xFF15803D),
              const Color(0xFFBBF7D0),
            ),
            'rejected' || 'invalid' || 'cancelled' || 'canceled' => (
              const Color(0xFFFEE2E2),
              const Color(0xFFB91C1C),
              const Color(0xFFFECACA),
            ),
            _ => (
              TabangNowTheme.of(context).surfaceSoft,
              TabangNowTheme.of(context).textSoft,
              TabangNowTheme.of(context).border,
            ),
          };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _labelFromKey(value),
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _IncidentMap extends StatelessWidget {
  const _IncidentMap({required this.point});

  static const LatLng _daoCenter = LatLng(11.3945, 122.6858);

  final LatLng? point;

  @override
  Widget build(BuildContext context) {
    final center = point ?? _daoCenter;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 360,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: point == null ? 13 : 16,
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.tabangnow_flutter',
            ),
            if (point != null)
              MarkerLayer(
                markers: <Marker>[
                  Marker(
                    point: point!,
                    width: 38,
                    height: 38,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFF172554),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x660F172A),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            const RichAttributionWidget(
              attributions: <SourceAttribution>[
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FullMapPreviewScreen extends StatelessWidget {
  const _FullMapPreviewScreen({required this.point, required this.title});

  final LatLng point;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FlutterMap(
        options: MapOptions(initialCenter: point, initialZoom: 17),
        children: <Widget>[
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.tabangnow_flutter',
          ),
          MarkerLayer(
            markers: <Marker>[
              Marker(
                point: point,
                width: 42,
                height: 42,
                child: const Icon(
                  Icons.location_pin,
                  color: Color(0xFF172554),
                  size: 42,
                ),
              ),
            ],
          ),
          const RichAttributionWidget(
            attributions: <SourceAttribution>[
              TextSourceAttribution('OpenStreetMap contributors'),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({
    required this.incidentService,
    required this.incidentId,
    required this.evidence,
    required this.onOpen,
  });

  final IncidentService incidentService;
  final int incidentId;
  final Map<String, dynamic> evidence;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final evidenceId = _toInt(evidence['id']);
    final mime = evidence['mime_type']?.toString().toLowerCase() ?? '';
    final type = evidence['file_type']?.toString().toLowerCase() ?? '';
    final isImage =
        mime.startsWith('image/') ||
        <String>['jpg', 'jpeg', 'png', 'webp'].contains(type);

    final fileName = evidence['file_name']?.toString() ?? 'Attachment';
    final uploader = _map(evidence['uploaded_by']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: TabangNowTheme.of(context).surfaceMuted,
        border: Border.all(color: TabangNowTheme.of(context).border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isImage && evidenceId != null)
            FutureBuilder<Uint8List>(
              future: incidentService.evidenceBytes(
                incidentId: incidentId,
                evidenceId: evidenceId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 170,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 140,
                    child: Center(
                      child: Icon(Icons.image_not_supported_outlined, size: 42),
                    ),
                  );
                }

                return Image.memory(
                  snapshot.data!,
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                );
              },
            )
          else
            SizedBox(
              height: 140,
              child: Center(
                child: Icon(
                  Icons.attach_file_rounded,
                  size: 46,
                  color: TabangNowTheme.of(context).textSoft,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: TabangNowTheme.of(context).textMain,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((uploader['name']?.toString().trim() ?? '')
                    .isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Uploaded by ${uploader['name']}',
                    style: TextStyle(
                      color: TabangNowTheme.of(context).textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open File'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedCasesSection extends StatelessWidget {
  const _RelatedCasesSection({
    required this.relatedCases,
    required this.onCreateCase,
  });

  final List<Map<String, dynamic>> relatedCases;
  final VoidCallback? onCreateCase;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: 'Related Cases',
      subtitle: 'Barangay case records connected to this incident.',
      child: relatedCases.isEmpty
          ? Column(
              children: <Widget>[
                const _EmptyPanel(
                  icon: Icons.folder_open_rounded,
                  title: 'No related case yet',
                  message:
                      'Create a case record if this incident needs '
                      'formal barangay handling.',
                ),
                if (onCreateCase != null) ...<Widget>[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onCreateCase,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create Case'),
                    ),
                  ),
                ],
              ],
            )
          : Column(
              children: relatedCases
                  .map((caseRecord) => _RelatedCaseCard(caseRecord: caseRecord))
                  .toList(),
            ),
    );
  }
}

class _RelatedCaseCard extends StatelessWidget {
  const _RelatedCaseCard({required this.caseRecord});

  final Map<String, dynamic> caseRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TabangNowTheme.of(context).surfaceMuted,
        border: Border.all(color: TabangNowTheme.of(context).border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Case No. '
            '${caseRecord['case_number'] ?? caseRecord['id'] ?? '—'}',
            style: const TextStyle(
              color: Color(0xFF1D4ED8),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _CompactLine(
            label: 'Type',
            value: caseRecord['case_type_label']?.toString() ?? '—',
          ),
          _CompactLine(
            label: 'Status',
            value: caseRecord['status_label']?.toString() ?? '—',
          ),
          _CompactLine(
            label: 'Hearing Date',
            value: caseRecord['hearing_date']?.toString() ?? 'No hearing date',
          ),
          _CompactLine(
            label: 'Handled By',
            value: caseRecord['handled_by']?.toString() ?? 'Not assigned',
          ),
        ],
      ),
    );
  }
}

class _CompactLine extends StatelessWidget {
  const _CompactLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: TabangNowTheme.of(context).textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: TabangNowTheme.of(context).textSoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHistorySection extends StatelessWidget {
  const _StatusHistorySection({required this.histories});

  final List<Map<String, dynamic>> histories;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: 'Status History',
      subtitle: 'Timeline of updates for this incident.',
      child: histories.isEmpty
          ? const _EmptyPanel(
              icon: Icons.schedule_rounded,
              title: 'No status history yet',
              message:
                  'Updates will appear here once this '
                  'incident is processed.',
            )
          : Column(
              children: histories
                  .map((history) => _StatusHistoryItem(history: history))
                  .toList(),
            ),
    );
  }
}

class _StatusHistoryItem extends StatelessWidget {
  const _StatusHistoryItem({required this.history});

  final Map<String, dynamic> history;

  @override
  Widget build(BuildContext context) {
    final updater = _map(history['updated_by']);
    final changedAt = _parseDate(history['status_changed_at']);
    final status = history['status']?.toString() ?? 'Updated';
    final remarks = history['remarks']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.only(left: 14, bottom: 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: TabangNowTheme.of(context).borderStrong,
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _IncidentBadge(value: status, kind: _BadgeKind.status),
              if (changedAt != null)
                Text(
                  '${_formatShortDate(changedAt)} '
                  '${_formatTime(changedAt)}',
                  style: TextStyle(
                    color: TabangNowTheme.of(context).textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Updated by '
            '${updater['name']?.toString() ?? 'System'}',
            style: TextStyle(
              color: TabangNowTheme.of(context).textMain,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (remarks.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              remarks,
              style: TextStyle(
                color: TabangNowTheme.of(context).textMuted,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: TabangNowTheme.of(context).surfaceMuted,
        border: Border.all(color: TabangNowTheme.of(context).borderStrong),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 36, color: TabangNowTheme.of(context).textMuted),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: TabangNowTheme.of(context).textMain,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: TabangNowTheme.of(context).textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageEvidenceScreen extends StatelessWidget {
  const _ImageEvidenceScreen({required this.title, required this.bytes});

  final String title;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Center(child: Image.memory(bytes)),
      ),
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

int? _toInt(Object? value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '');
}

DateTime? _parseDate(Object? value) {
  final raw = value?.toString().trim();

  if (raw == null || raw.isEmpty) {
    return null;
  }

  return DateTime.tryParse(raw)?.toLocal();
}

String _formatLongDate(DateTime date) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${months[date.month - 1]} '
      '${date.day.toString().padLeft(2, '0')}, '
      '${date.year}';
}

String _formatShortDate(DateTime date) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[date.month - 1]} '
      '${date.day.toString().padLeft(2, '0')}, '
      '${date.year}';
}

String _formatTime(DateTime date) {
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';

  return '${hour12.toString().padLeft(2, '0')}:'
      '$minute $suffix';
}

String _labelFromKey(String value) {
  final trimmed = value.trim();

  if (trimmed.isEmpty) {
    return 'Unknown';
  }

  return trimmed
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .map(
        (part) => part.isEmpty
            ? ''
            : '${part[0].toUpperCase()}'
                  '${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _safeFileName(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return cleaned.isEmpty ? 'evidence' : cleaned;
}

BoxDecoration _panelDecoration(BuildContext context) {
  return BoxDecoration(
    color: TabangNowTheme.of(context).surface,
    border: Border.all(color: TabangNowTheme.of(context).border),
    borderRadius: BorderRadius.circular(16),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );
}
