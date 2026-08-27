import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_capabilities.dart';
import '../core/app_role.dart';
import '../core/tabangnow_theme.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.authService,
    required this.user,
  });

  final AuthService authService;
  final Map<String, dynamic> user;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ReportService _service;

  bool _loading = true;
  bool _pdfBusy = false;
  bool _showAllRecords = false;
  String? _error;

  String _period = 'week';

  Map<String, dynamic> _data = <String, dynamic>{};

  List<Map<String, dynamic>> _periodOptions = <Map<String, dynamic>>[
    <String, dynamic>{'value': 'today', 'label': 'Today'},
    <String, dynamic>{'value': 'week', 'label': 'This Week'},
    <String, dynamic>{'value': 'month', 'label': 'This Month'},
    <String, dynamic>{'value': 'year', 'label': 'This Year'},
  ];

  AppRole get _role => AppRoleX.fromRaw(
    widget.user['role']?.toString().trim().toLowerCase() ?? '',
  );

  AppCapabilitySet get _capabilities => AppCapabilities.forRole(_role);

  bool get _canViewReports => _capabilities.allows(AppCapability.viewReports);

  @override
  void initState() {
    super.initState();

    _service = ReportService(authService: widget.authService);

    _load();
  }

  Future<void> _load() async {
    if (!_canViewReports) {
      setState(() {
        _loading = false;
        _error = 'Reports are not available for this account.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _service.index(period: _period);

      if (!mounted) {
        return;
      }

      final data = _map(response['data']);

      final options = _mapList(response['period_options']);

      final serverPeriod = _text(data['period'], _period);

      setState(() {
        _data = data;

        if (options.isNotEmpty) {
          _periodOptions = options;
        }

        _period = serverPeriod;
        _showAllRecords = false;
        _loading = false;
        _error = null;
      });
    } catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = exception.toString().replaceFirst('AuthException: ', '');
      });
    }
  }

  Future<void> _changePeriod(String? value) async {
    if (value == null || value == _period) {
      return;
    }

    setState(() {
      _period = value;
    });

    await _load();
  }

  Future<void> _downloadPeriodPdf() async {
    await _generatePdf(() => _service.periodPdf(period: _period));
  }

  Future<void> _selectSpecificPdf(_SpecificReportKind kind) async {
    final reportOptions = _map(_data['report_options']);

    final options = switch (kind) {
      _SpecificReportKind.incident => _mapList(reportOptions['incidents']),
      _SpecificReportKind.caseRecord => _mapList(reportOptions['cases']),
      _SpecificReportKind.complaint => _mapList(reportOptions['complaints']),
      _SpecificReportKind.sos => _mapList(reportOptions['sos']),
    };

    if (options.isEmpty) {
      _show(
        'No ${kind.pluralLabel.toLowerCase()} are available for PDF generation.',
      );
      return;
    }

    final selectedId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TabangNowTheme.of(context).surface,
      builder: (_) => _SpecificReportPicker(kind: kind, options: options),
    );

    if (selectedId == null || !mounted) {
      return;
    }

    await _generatePdf(
      () => switch (kind) {
        _SpecificReportKind.incident => _service.incidentPdf(selectedId),
        _SpecificReportKind.caseRecord => _service.casePdf(selectedId),
        _SpecificReportKind.complaint => _service.complaintPdf(selectedId),
        _SpecificReportKind.sos => _service.sosPdf(selectedId),
      },
    );
  }

  Future<void> _generatePdf(
    Future<DownloadedReportPdf> Function() generate,
  ) async {
    if (_pdfBusy) {
      return;
    }

    setState(() {
      _pdfBusy = true;
    });

    try {
      final pdf = await generate();

      final savedFile = await _savePdfCopy(pdf);

      if (!mounted) {
        return;
      }

      _show(
        'PDF saved as ${pdf.fileName}. Opening it now. Use the PDF viewer Print/Share menu for a physical or digital copy.',
      );

      final result = await OpenFilex.open(savedFile.path);

      if (result.type != ResultType.done && mounted) {
        _show(
          result.message.isNotEmpty
              ? result.message
              : 'The PDF was saved, but no compatible PDF viewer could open it.',
        );
      }
    } catch (exception) {
      if (mounted) {
        _show(exception.toString().replaceFirst('AuthException: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _pdfBusy = false;
        });
      }
    }
  }

  Future<File> _savePdfCopy(DownloadedReportPdf pdf) async {
    final documents = await getApplicationDocumentsDirectory();

    final reportDirectory = Directory(
      '${documents.path}${Platform.pathSeparator}TabangNow Reports',
    );

    if (!await reportDirectory.exists()) {
      await reportDirectory.create(recursive: true);
    }

    final file = File(
      '${reportDirectory.path}${Platform.pathSeparator}${pdf.fileName}',
    );

    await file.writeAsBytes(pdf.bytes, flush: true);

    return file;
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    if (!_canViewReports) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const <Widget>[
          SizedBox(height: 100),
          Icon(Icons.lock_outline_rounded, size: 48),
          SizedBox(height: 14),
          Text(
            'Reports are restricted to administrator accounts.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final summary = _map(_data['summary']);

    final records = _mapList(_data['records']);

    final tanodSummary = _mapList(_data['tanod_summary']);

    final visibleRecords = _showAllRecords
        ? records
        : records.take(5).toList(growable: false);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Reports',
                      style: TextStyle(
                        color: palette.textMain,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Dao, Capiz — ${_text(_data['period_label'], 'This Week')}',
                      style: TextStyle(color: palette.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 145,
                child: DropdownButtonFormField<String>(
                  initialValue: _period,
                  decoration: const InputDecoration(
                    labelText: 'Period',
                    isDense: true,
                  ),
                  items: _periodOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option['value']?.toString(),
                          child: Text(
                            option['label']?.toString() ??
                                option['value']?.toString() ??
                                '',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _loading ? null : _changePeriod,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _PdfActionsCard(
            busy: _pdfBusy,
            onIncident: () => _selectSpecificPdf(_SpecificReportKind.incident),
            onCase: () => _selectSpecificPdf(_SpecificReportKind.caseRecord),
            onComplaint: () =>
                _selectSpecificPdf(_SpecificReportKind.complaint),
            onSos: () => _selectSpecificPdf(_SpecificReportKind.sos),
            onPeriod: _downloadPeriodPdf,
          ),

          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 110),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else ...<Widget>[
            _SummaryGrid(
              totalIncidents: _int(summary['total_incidents']),
              activeIncidents: _int(summary['active_incidents']),
              resolvedIncidents: _int(summary['resolved_incidents']),
              casesFiled: _int(summary['cases_filed']),
            ),
            const SizedBox(height: 16),
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${_text(_data['period_label'], 'This Week')} Records Breakdown',
                    style: TextStyle(
                      color: palette.textMain,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Incidents, cases, and announcements recorded within the selected period.',
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (records.isEmpty)
                    _EmptyPanel(
                      title: 'No records found',
                      message:
                          'There are no recorded activities for ${_text(_data['period_label'], 'this period').toLowerCase()}.',
                    )
                  else ...<Widget>[
                    for (
                      var index = 0;
                      index < visibleRecords.length;
                      index++
                    ) ...<Widget>[
                      _RecordCard(record: visibleRecords[index]),
                      if (index != visibleRecords.length - 1)
                        const Divider(height: 24),
                    ],
                    if (records.length > 5) ...<Widget>[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showAllRecords = !_showAllRecords;
                            });
                          },
                          icon: Icon(
                            _showAllRecords
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                          ),
                          label: Text(
                            _showAllRecords
                                ? 'Show Less'
                                : 'Show All ${records.length} Records',
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _showAllRecords
                            ? 'Showing all ${records.length} records'
                            : 'Showing 5 of ${records.length} records',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Tanod Response Summary',
                    style: TextStyle(
                      color: palette.textMain,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Acceptance and decline activity from Tanod Tasks within the selected period.',
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (tanodSummary.isEmpty)
                    const _EmptyPanel(
                      title: 'No tanod task responses in this period',
                      message:
                          'Response data will appear when tanods accept or decline tasks.',
                    )
                  else
                    for (
                      var index = 0;
                      index < tanodSummary.length;
                      index++
                    ) ...<Widget>[
                      _TanodSummaryCard(row: tanodSummary[index]),
                      if (index != tanodSummary.length - 1)
                        const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Generated by ${_text(_data['generated_by'], 'System')}',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PdfActionsCard extends StatelessWidget {
  const _PdfActionsCard({
    required this.busy,
    required this.onIncident,
    required this.onCase,
    required this.onComplaint,
    required this.onSos,
    required this.onPeriod,
  });

  final bool busy;
  final VoidCallback onIncident;
  final VoidCallback onCase;
  final VoidCallback onComplaint;
  final VoidCallback onSos;
  final VoidCallback onPeriod;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.picture_as_pdf_rounded, color: palette.accentText),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'PDF Reports',
                  style: TextStyle(
                    color: palette.textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Generate the same A4 PDF reports used by the website. The file is saved on the phone and opened in the installed PDF viewer for printing or sharing.',
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: busy ? null : onIncident,
                icon: const Icon(Icons.description_outlined),
                label: const Text('Incident PDF'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onCase,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Case PDF'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onComplaint,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Complaint PDF'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onSos,
                icon: const Icon(Icons.emergency_outlined),
                label: const Text('SOS PDF'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : onPeriod,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.totalIncidents,
    required this.activeIncidents,
    required this.resolvedIncidents,
    required this.casesFiled,
  });

  final int totalIncidents;
  final int activeIncidents;
  final int resolvedIncidents;
  final int casesFiled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _SummaryCard(
              width: width,
              label: 'Total Incidents',
              value: totalIncidents,
              semantic: _SummarySemantic.primary,
            ),
            _SummaryCard(
              width: width,
              label: 'Active / Pending',
              value: activeIncidents,
              semantic: _SummarySemantic.warning,
            ),
            _SummaryCard(
              width: width,
              label: 'Resolved',
              value: resolvedIncidents,
              semantic: _SummarySemantic.success,
            ),
            _SummaryCard(
              width: width,
              label: 'Cases Filed',
              value: casesFiled,
              semantic: _SummarySemantic.indigo,
            ),
          ],
        );
      },
    );
  }
}

enum _SummarySemantic { primary, warning, success, indigo }

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.label,
    required this.value,
    required this.semantic,
  });

  final double width;
  final String label;
  final int value;
  final _SummarySemantic semantic;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final accent = switch (semantic) {
      _SummarySemantic.primary => palette.accentText,
      _SummarySemantic.warning =>
        palette.isDark ? const Color(0xFFFDBA74) : const Color(0xFFEA580C),
      _SummarySemantic.success =>
        palette.isDark ? const Color(0xFF86EFAC) : const Color(0xFF16A34A),
      _SummarySemantic.indigo =>
        palette.isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
    };

    return Container(
      width: width,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.45,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            value.toString(),
            style: TextStyle(
              color: accent,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _text(record['category'], 'Record'),
                style: TextStyle(
                  color: palette.accentText,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Spacer(),
            Text(
              _text(record['datetime'], '—'),
              style: TextStyle(color: palette.textMuted, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          _text(record['title'], 'Untitled record'),
          style: TextStyle(
            color: palette.textMain,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: <Widget>[
            _TinyMeta(label: 'Severity', value: _text(record['severity'], '—')),
            _TinyMeta(label: 'Barangay', value: _text(record['barangay'], '—')),
            _TinyMeta(label: 'Status', value: _text(record['status'], '—')),
          ],
        ),
      ],
    );
  }
}

class _TanodSummaryCard extends StatelessWidget {
  const _TanodSummaryCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _text(row['name'], 'Tanod'),
            style: TextStyle(
              color: palette.textMain,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: <Widget>[
              _TinyMeta(
                label: 'Total Tasks',
                value: _int(row['total_tasks']).toString(),
              ),
              _TinyMeta(
                label: 'Accepted',
                value: _int(row['accepted']).toString(),
              ),
              _TinyMeta(
                label: 'Declined',
                value: _int(row['declined']).toString(),
              ),
              _TinyMeta(
                label: 'Pending',
                value: _int(row['pending']).toString(),
              ),
              _TinyMeta(
                label: 'Response Rate',
                value: '${_int(row['response_rate'])}%',
              ),
              _TinyMeta(
                label: 'Last Response',
                value: _text(row['last_response'], 'No response yet'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyMeta extends StatelessWidget {
  const _TinyMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 90, maxWidth: 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: palette.textSoft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textMain,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

enum _SpecificReportKind {
  incident,
  caseRecord,
  complaint,
  sos;

  String get title => switch (this) {
    _SpecificReportKind.incident => 'Incident Report',
    _SpecificReportKind.caseRecord => 'Case Report',
    _SpecificReportKind.complaint => 'Complaint Report',
    _SpecificReportKind.sos => 'SOS / Distress Signal Report',
  };

  String get singularLabel => switch (this) {
    _SpecificReportKind.incident => 'incident',
    _SpecificReportKind.caseRecord => 'case',
    _SpecificReportKind.complaint => 'complaint',
    _SpecificReportKind.sos => 'SOS / Distress Signal',
  };

  String get pluralLabel => switch (this) {
    _SpecificReportKind.incident => 'Incidents',
    _SpecificReportKind.caseRecord => 'Cases',
    _SpecificReportKind.complaint => 'Complaints',
    _SpecificReportKind.sos => 'SOS / Distress Signals',
  };
}

class _SpecificReportPicker extends StatefulWidget {
  const _SpecificReportPicker({required this.kind, required this.options});

  final _SpecificReportKind kind;
  final List<Map<String, dynamic>> options;

  @override
  State<_SpecificReportPicker> createState() => _SpecificReportPickerState();
}

class _SpecificReportPickerState extends State<_SpecificReportPicker> {
  final _searchController = TextEditingController();

  int? _selectedId;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _query.trim().toLowerCase();

    if (query.isEmpty) {
      return widget.options;
    }

    return widget.options
        .where(
          (option) => _text(option['label'], '').toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final height = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.kind.title,
                    style: TextStyle(
                      color: palette.textMain,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Generate a separate PDF report for one selected ${widget.kind.singularLabel} only.',
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search ${widget.kind.pluralLabel}',
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final option = _filtered[index];

                  final id = _int(option['id']);

                  final selected = _selectedId == id;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      enabled: id > 0,
                      selected: selected,
                      leading: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected
                            ? palette.accentText
                            : palette.textMuted,
                      ),
                      title: Text(
                        _text(option['label'], '${widget.kind.title} #$id'),
                      ),
                      onTap: id <= 0
                          ? null
                          : () {
                              setState(() {
                                _selectedId = id;
                              });
                            },
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(top: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _selectedId == null
                          ? null
                          : () => Navigator.of(context).pop(_selectedId),
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('Generate PDF'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) {
    return <Map<String, dynamic>>[];
  }

  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _text(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? fallback : text;
}
