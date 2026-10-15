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
  String? _error;
  String _period = 'week';
  String _metric = 'total';
  DateTimeRange? _customRange;
  Map<String, dynamic> _data = <String, dynamic>{};

  List<Map<String, dynamic>> _periodOptions = <Map<String, dynamic>>[
    <String, dynamic>{'value': 'today', 'label': 'Today'},
    <String, dynamic>{'value': 'week', 'label': 'Last 7 Days'},
    <String, dynamic>{'value': 'month', 'label': 'Last 30 Days'},
    <String, dynamic>{'value': 'year', 'label': 'This Year'},
    <String, dynamic>{'value': 'custom', 'label': 'Custom / Previous Dates'},
  ];

  AppRole get _role => AppRoleX.fromRaw(
    widget.user['role']?.toString().trim().toLowerCase() ?? '',
  );

  AppCapabilitySet get _capabilities => AppCapabilities.forRole(_role);

  bool get _canViewReports => _capabilities.allows(AppCapability.viewReports);

  String? get _dateFrom =>
      _customRange == null ? null : _dateString(_customRange!.start);

  String? get _dateTo =>
      _customRange == null ? null : _dateString(_customRange!.end);

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
      final response = await _service.index(
        period: _period,
        metric: _metric,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      if (!mounted) {
        return;
      }

      final data = _map(response['data']);
      final options = _mapList(response['period_options']);
      final serverPeriod = _text(data['period'], _period);
      final serverMetric = _text(data['selected_metric'], _metric);

      if (serverPeriod == 'custom') {
        final from = _tryDate(data['date_from']);
        final to = _tryDate(data['date_to']);

        if (from != null && to != null) {
          _customRange = DateTimeRange(start: from, end: to);
        }
      }

      setState(() {
        _data = data;
        if (options.isNotEmpty) {
          _periodOptions = options;
        }
        _period = serverPeriod;
        _metric = serverMetric;
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

    if (value == 'custom') {
      final now = DateTime.now();
      final initial =
          _customRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);

      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 10, 1, 1),
        lastDate: DateTime(now.year, now.month, now.day),
        initialDateRange: initial,
        helpText: 'Select previous report dates',
        saveText: 'APPLY',
      );

      if (picked == null || !mounted) {
        return;
      }

      setState(() {
        _period = 'custom';
        _customRange = picked;
      });

      await _load();
      return;
    }

    setState(() {
      _period = value;
      _customRange = null;
    });

    await _load();
  }

  Future<void> _selectMetric(String metric) async {
    if (_loading || metric == _metric) {
      return;
    }

    setState(() {
      _metric = metric;
    });

    await _load();
  }

  Future<void> _downloadMetricPdf([String? metric]) async {
    final targetMetric = metric ?? _metric;

    await _generatePdf(
      () => _service.metricPdf(
        period: _period,
        metric: targetMetric,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      ),
    );
  }

  Future<void> _selectRecordsPdf() async {
    final records = _mapList(_data['records']);

    if (records.isEmpty) {
      _show('There are no records to download for this metric and timeline.');
      return;
    }

    final selectable = records
        .where((record) => _text(record['record_key']).isNotEmpty)
        .toList(growable: false);

    if (selectable.length != records.length) {
      _show(
        'The API did not provide selection keys for every record. Refresh Reports after the Laravel Patch 05A API update.',
      );
      return;
    }

    final selected = <String>{};

    final choice = await showModalBottomSheet<_PdfSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TabangNowTheme.of(context).surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final palette = TabangNowTheme.of(context);

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.86,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Select Records for PDF',
                        style: TextStyle(
                          color: palette.textMain,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedMetricLabel()} · ${_periodLabel()}',
                        style: TextStyle(color: palette.textMuted),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: selectable.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final record = selectable[index];
                            final key = _text(record['record_key']);
                            final checked = selected.contains(key);

                            return CheckboxListTile(
                              value: checked,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _text(record['title'], 'Untitled record'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${_text(record['category'], 'Record')} · ${_text(record['datetime'], '—')}',
                              ),
                              onChanged: (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    selected.add(key);
                                  } else {
                                    selected.remove(key);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(sheetContext).pop(
                                  const _PdfSelection(
                                    all: true,
                                    keys: <String>[],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.select_all_rounded),
                              label: const Text('Download All'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: selected.isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(sheetContext).pop(
                                        _PdfSelection(
                                          all: false,
                                          keys: selected.toList(
                                            growable: false,
                                          ),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.download_rounded),
                              label: Text('Selected (${selected.length})'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (choice == null || !mounted) {
      return;
    }

    await _generatePdf(
      () => _service.selectedPdf(
        period: _period,
        metric: _metric,
        selectionMode: choice.all ? 'all' : 'selected',
        recordKeys: choice.keys,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      ),
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: <Widget>[
          // REPORTS_RESPONSIVE_HEADER_V1
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;

              final heading = Column(
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
                    'Dao, Capiz — ${_periodLabel()}',
                    style: TextStyle(color: palette.textMuted),
                  ),
                  if (_period == 'custom' && _customRange != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      '${_dateFrom ?? ''} to ${_dateTo ?? ''}',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              );

              final timeline = SizedBox(
                width: compact ? double.infinity : 170,
                child: DropdownButtonFormField<String>(
                  initialValue: _period,
                  decoration: const InputDecoration(
                    labelText: 'Timeline',
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _loading ? null : _changePeriod,
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    heading,
                    const SizedBox(height: 14),
                    timeline,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: heading),
                  const SizedBox(width: 12),
                  timeline,
                ],
              );
            },
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
            _MetricGrid(
              selectedMetric: _metric,
              busy: _pdfBusy,
              metrics: <_MetricDefinition>[
                _MetricDefinition(
                  key: 'total',
                  label: 'Total Incidents',
                  value: _int(summary['total_incidents']),
                  helper: 'All incident records in the selected timeline',
                ),
                _MetricDefinition(
                  key: 'active',
                  label: 'Active Incidents',
                  value: _int(summary['active_incidents']),
                  helper: 'All current non-terminal incident statuses',
                ),
                _MetricDefinition(
                  key: 'critical',
                  label: 'Critical Incidents',
                  value: _int(summary['critical_incidents']),
                  helper: 'Unresolved critical-priority incidents',
                ),
                _MetricDefinition(
                  key: 'resolved',
                  label: 'Resolved Incidents',
                  value: _int(summary['resolved_incidents']),
                  helper: 'Resolved / completed / closed incidents',
                ),
                _MetricDefinition(
                  key: 'distress',
                  label: 'Distress Signals / SOS',
                  value: _int(summary['distress_signals']),
                  helper: 'Emergency SOS records in the selected timeline',
                ),
                _MetricDefinition(
                  key: 'tanod',
                  label: 'Tanod On Duty',
                  value: _int(summary['tanod_on_duty']),
                  helper: 'Current Tanod roster duty status',
                ),
              ],
              onSelect: _selectMetric,
              onDownload: _downloadMetricPdf,
            ),
            const SizedBox(height: 16),
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${_selectedMetricLabel()} Records Breakdown',
                              style: TextStyle(
                                color: palette.textMain,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${_periodLabel()} · Tap any record to preview it without leaving Reports.',
                              style: TextStyle(
                                color: palette.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: records.isEmpty || _pdfBusy
                            ? null
                            : _selectRecordsPdf,
                        icon: const Icon(Icons.checklist_rounded),
                        label: const Text('Select Records PDF'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (records.isEmpty)
                    _EmptyPanel(
                      title: 'No records found',
                      message:
                          'No ${_selectedMetricLabel().toLowerCase()} records were recorded during ${_periodLabel().toLowerCase()}.',
                    )
                  else
                    for (
                      var index = 0;
                      index < records.length;
                      index++
                    ) ...<Widget>[
                      _RecordCard(
                        record: records[index],
                        onTap: () => _showRecordPreview(records[index]),
                      ),
                      if (index != records.length - 1)
                        const Divider(height: 24),
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

  Future<void> _showRecordPreview(Map<String, dynamic> record) async {
    final palette = TabangNowTheme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Record Preview',
                          style: TextStyle(
                            color: palette.textMain,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PreviewRow(
                    label: 'Category',
                    value: _text(record['category'], '—'),
                  ),
                  _PreviewRow(
                    label: 'Details',
                    value: _text(record['title'], '—'),
                  ),
                  _PreviewRow(
                    label: 'Severity',
                    value: _text(record['severity'], '—'),
                  ),
                  _PreviewRow(
                    label: 'Barangay Areas',
                    value: _text(record['barangay'], '—'),
                  ),
                  _PreviewRow(
                    label: 'Status',
                    value: _text(record['status'], '—'),
                  ),
                  _PreviewRow(
                    label: 'Date & Time',
                    value: _text(record['datetime'], '—'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _periodLabel() =>
      _text(_data['period_label'], _fallbackPeriodLabel(_period));

  String _selectedMetricLabel() =>
      _text(_data['selected_metric_label'], _fallbackMetricLabel(_metric));

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.selectedMetric,
    required this.busy,
    required this.metrics,
    required this.onSelect,
    required this.onDownload,
  });

  final String selectedMetric;
  final bool busy;
  final List<_MetricDefinition> metrics;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDownload;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics
              .map(
                (metric) => _MetricCard(
                  width: width,
                  metric: metric,
                  selected: metric.key == selectedMetric,
                  busy: busy,
                  onSelect: () => onSelect(metric.key),
                  onDownload: () => onDownload(metric.key),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.metric,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onDownload,
  });

  final double width;
  final _MetricDefinition metric;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? palette.accentSoft : palette.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: selected ? palette.accentText : palette.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: onSelect,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          metric.label.toUpperCase(),
                          style: TextStyle(
                            color: palette.accentText,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.35,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: palette.accentText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metric.value.toString(),
                    style: TextStyle(
                      color: palette.textMain,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    metric.helper,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onDownload,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
              label: const Text('Download PDF'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onTap});

  final Map<String, dynamic> record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
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
                Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: palette.textMuted,
                ),
                const SizedBox(width: 5),
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
                _TinyMeta(
                  label: 'Severity',
                  value: _text(record['severity'], '—'),
                ),
                _TinyMeta(
                  label: 'Barangay',
                  value: _text(record['barangay'], '—'),
                ),
                _TinyMeta(label: 'Status', value: _text(record['status'], '—')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: palette.textMain,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
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

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: palette.textMain,
              fontSize: 10,
              fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.all(16),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(15),
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
          const SizedBox(height: 6),
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
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return _Surface(
      child: Column(
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, size: 42),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMain),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _MetricDefinition {
  const _MetricDefinition({
    required this.key,
    required this.label,
    required this.value,
    required this.helper,
  });

  final String key;
  final String label;
  final int value;
  final String helper;
}

class _PdfSelection {
  const _PdfSelection({required this.all, required this.keys});

  final bool all;
  final List<String> keys;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) {
    return <Map<String, dynamic>>[];
  }

  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

String _text(dynamic value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? fallback : text;
}

int _int(dynamic value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _tryDate(dynamic value) {
  final raw = value?.toString().trim() ?? '';

  if (raw.isEmpty) {
    return null;
  }

  return DateTime.tryParse(raw);
}

String _dateString(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
}

String _fallbackPeriodLabel(String period) {
  return switch (period) {
    'today' => 'Today',
    'week' => 'Last 7 Days',
    'month' => 'Last 30 Days',
    'year' => 'This Year',
    'custom' => 'Custom / Previous Dates',
    _ => 'Reports',
  };
}

String _fallbackMetricLabel(String metric) {
  return switch (metric) {
    'active' => 'Active Incidents',
    'critical' => 'Critical Incidents',
    'resolved' => 'Resolved Incidents',
    'distress' => 'Distress Signals / SOS',
    'tanod' => 'Tanod On Duty',
    _ => 'Total Incidents',
  };
}
