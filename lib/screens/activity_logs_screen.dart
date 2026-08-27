import 'package:flutter/material.dart';

import '../core/app_capabilities.dart';
import '../core/app_role.dart';
import '../core/tabangnow_theme.dart';
import '../services/activity_log_service.dart';
import '../services/auth_service.dart';
import 'activity_log_detail_screen.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({
    super.key,
    required this.authService,
    required this.user,
  });

  final AuthService authService;
  final Map<String, dynamic> user;

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  late final ActivityLogService _service;

  final _searchController = TextEditingController();

  bool _loading = true;
  bool _deletingAll = false;
  bool _canDeleteAll = false;
  String? _error;

  List<Map<String, dynamic>> _logs = <Map<String, dynamic>>[];

  Map<String, dynamic> _options = <String, dynamic>{};

  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  int _perPage = 50;

  String _category = '';
  String _event = '';
  int? _actorId;
  String _dateFrom = '';
  String _dateTo = '';

  AppRole get _role => AppRoleX.fromRaw(
    widget.user['role']?.toString().trim().toLowerCase() ?? '',
  );

  bool get _canView =>
      AppCapabilities.forRole(_role).allows(AppCapability.viewActivityLogs);

  @override
  void initState() {
    super.initState();

    _service = ActivityLogService(authService: widget.authService);

    _load(page: 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({required int page}) async {
    if (!_canView) {
      setState(() {
        _loading = false;
        _error = 'Activity Logs are restricted to administrator accounts.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _service.index(
        page: page,
        perPage: _perPage,
        search: _searchController.text,
        category: _category,
        event: _event,
        actorId: _actorId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      if (!mounted) {
        return;
      }

      final pagination = _map(response['pagination']);

      final filters = _map(response['filters']);

      setState(() {
        _logs = _mapList(response['data']);

        _options = _map(response['options']);

        _canDeleteAll = _map(response['permissions'])['can_delete_all'] == true;

        _page = _int(pagination['current_page'], fallback: page);

        _lastPage = _int(pagination['last_page'], fallback: 1);

        _total = _int(pagination['total']);

        _perPage = _int(filters['per_page'], fallback: 50);

        _loading = false;
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

  Future<void> _applySearch() async {
    _page = 1;
    await _load(page: 1);
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    setState(() {
      _category = '';
      _event = '';
      _actorId = null;
      _dateFrom = '';
      _dateTo = '';
      _perPage = 50;
      _page = 1;
    });

    await _load(page: 1);
  }

  Future<void> _openFilters() async {
    var category = _category;
    var event = _event;
    var actorId = _actorId;
    var dateFrom = _dateFrom;
    var dateTo = _dateTo;
    var perPage = _perPage;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TabangNowTheme.of(context).surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final palette = TabangNowTheme.of(context);

            final categories = _stringList(_options['categories']);

            final events = _stringList(_options['events']);

            final actors = _mapList(_options['actors']);

            final pageSizes = _intList(
              _options['per_page'],
              fallback: const <int>[10, 25, 50, 100, 250],
            );

            Future<void> pickDate({required bool from}) async {
              final currentText = from ? dateFrom : dateTo;

              final initial = DateTime.tryParse(currentText) ?? DateTime.now();

              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );

              if (picked == null) {
                return;
              }

              setSheetState(() {
                final value = _dateValue(picked);

                if (from) {
                  dateFrom = value;

                  if (dateTo.isNotEmpty) {
                    final to = DateTime.tryParse(dateTo);

                    if (to != null && picked.isAfter(to)) {
                      dateTo = value;
                    }
                  }
                } else {
                  dateTo = value;
                }
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 18,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Activity Log Filters',
                        style: TextStyle(
                          color: palette.textMain,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Filter the read-only audit trail by category, event, actor, date range, and page size.',
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('All categories'),
                          ),
                          ...categories.map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(_pretty(value)),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setSheetState(() {
                            category = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: event,
                        decoration: const InputDecoration(labelText: 'Event'),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('All events'),
                          ),
                          ...events.map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(_pretty(value)),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setSheetState(() {
                            event = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: actorId?.toString() ?? '',
                        decoration: const InputDecoration(labelText: 'Actor'),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('All actors'),
                          ),
                          ...actors.map(
                            (actor) => DropdownMenuItem<String>(
                              value: _int(actor['id']).toString(),
                              child: Text(_text(actor['label'], 'Actor')),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setSheetState(() {
                            actorId = value == null || value.isEmpty
                                ? null
                                : int.tryParse(value);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _DateField(
                              label: 'Date from',
                              value: dateFrom,
                              onTap: () => pickDate(from: true),
                              onClear: dateFrom.isEmpty
                                  ? null
                                  : () {
                                      setSheetState(() {
                                        dateFrom = '';
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DateField(
                              label: 'Date to',
                              value: dateTo,
                              onTap: () => pickDate(from: false),
                              onClear: dateTo.isEmpty
                                  ? null
                                  : () {
                                      setSheetState(() {
                                        dateTo = '';
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: perPage,
                        decoration: const InputDecoration(labelText: 'Rows'),
                        items: pageSizes
                            .map(
                              (value) => DropdownMenuItem<int>(
                                value: value,
                                child: Text('$value per page'),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setSheetState(() {
                            perPage = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.of(sheetContext)
                                  .pop(<String, dynamic>{
                                    'category': category,
                                    'event': event,
                                    'actor_id': actorId,
                                    'date_from': dateFrom,
                                    'date_to': dateTo,
                                    'per_page': perPage,
                                  }),
                              child: const Text('Apply Filters'),
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

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _category = _text(result['category'], '');
      _event = _text(result['event'], '');
      _actorId = _nullableInt(result['actor_id']);
      _dateFrom = _text(result['date_from'], '');
      _dateTo = _text(result['date_to'], '');
      _perPage = _int(result['per_page'], fallback: 50);
      _page = 1;
    });

    await _load(page: 1);
  }

  Future<void> _deleteAllPermanently() async {
    if (_deletingAll || !_canDeleteAll) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete all activity logs permanently?'),
              content: const Text(
                'This will permanently remove the complete Activity Logs audit trail, not only the records shown by the current search or filters. This cannot be undone. New system activity will start creating fresh logs afterward.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Delete All Permanently'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _deletingAll = true;
    });

    try {
      final response = await _service.deleteAll();

      if (!mounted) {
        return;
      }

      _searchController.clear();

      setState(() {
        _category = '';
        _event = '';
        _actorId = null;
        _dateFrom = '';
        _dateTo = '';
        _perPage = 50;
        _page = 1;
      });

      await _load(page: 1);

      if (!mounted) {
        return;
      }

      final message = _text(
        response['message'],
        'Activity logs were permanently deleted.',
      );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                exception.toString().replaceFirst('AuthException: ', ''),
              ),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingAll = false;
        });
      }
    }
  }

  Future<void> _openLog(int activityLogId) async {
    if (activityLogId <= 0) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ActivityLogDetailScreen(
          service: _service,
          activityLogId: activityLogId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    if (!_canView) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const <Widget>[
          SizedBox(height: 100),
          Icon(Icons.lock_outline_rounded, size: 48),
          SizedBox(height: 14),
          Text(
            'Activity Logs are restricted to administrator accounts.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(page: _page),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: <Widget>[
          Text(
            'SECURITY AUDIT TRAIL',
            style: TextStyle(
              color: palette.accentText,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Activity Logs',
                      style: TextStyle(
                        color: palette.textMain,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review authentication, account-management, incident, complaint, tanod, announcement, configuration, and security events. Individual log records are read-only; administrators can permanently clear the full audit trail.',
                      style: TextStyle(color: palette.textMuted, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      _total.toString(),
                      style: TextStyle(
                        color: palette.textMain,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      _total == 1 ? 'MATCHING RECORD' : 'MATCHING RECORDS',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _Surface(
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _searchController,
                  maxLength: 200,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    hintText: 'Actor, event, description, route, or IP',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              _applySearch();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _applySearch(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _applySearch,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Apply'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _openFilters,
                      icon: const Icon(Icons.filter_alt_outlined),
                      label: const Text('Filters'),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Clear Filters',
                      onPressed: _loading ? null : _clearFilters,
                      icon: const Icon(Icons.filter_alt_off_outlined),
                    ),
                  ],
                ),
                if (_canDeleteAll) ...<Widget>[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB91C1C),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                      ),
                      onPressed: _loading || _deletingAll
                          ? null
                          : _deleteAllPermanently,
                      icon: _deletingAll
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_forever_outlined),
                      label: Text(
                        _deletingAll
                            ? 'Deleting Activity Logs...'
                            : 'Delete All Permanently',
                      ),
                    ),
                  ),
                ],
                if (_hasFilters) ...<Widget>[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        if (_category.isNotEmpty)
                          _FilterPill(label: 'Category: ${_pretty(_category)}'),
                        if (_event.isNotEmpty)
                          _FilterPill(label: 'Event: ${_pretty(_event)}'),
                        if (_actorId != null)
                          _FilterPill(label: 'Actor ID: $_actorId'),
                        if (_dateFrom.isNotEmpty)
                          _FilterPill(label: 'From: $_dateFrom'),
                        if (_dateTo.isNotEmpty)
                          _FilterPill(label: 'To: $_dateTo'),
                        if (_perPage != 25)
                          _FilterPill(label: 'Rows: $_perPage'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 100),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorCard(
              message: _error!,
              onRetry: () => _load(page: _page),
            )
          else if (_logs.isEmpty)
            const _EmptyCard()
          else
            for (var index = 0; index < _logs.length; index++) ...<Widget>[
              _ActivityLogCard(
                log: _logs[index],
                onOpen: () => _openLog(_int(_logs[index]['id'])),
              ),
              if (index != _logs.length - 1) const SizedBox(height: 10),
            ],

          if (!_loading && _error == null) ...<Widget>[
            const SizedBox(height: 16),
            _PaginationCard(
              page: _page,
              lastPage: _lastPage,
              total: _total,
              perPage: _perPage,
              onFirst: _page <= 1 ? null : () => _load(page: 1),
              onPrevious: _page <= 1 ? null : () => _load(page: _page - 1),
              onNext: _page >= _lastPage ? null : () => _load(page: _page + 1),
              onLast: _page >= _lastPage ? null : () => _load(page: _lastPage),
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasFilters =>
      _category.isNotEmpty ||
      _event.isNotEmpty ||
      _actorId != null ||
      _dateFrom.isNotEmpty ||
      _dateTo.isNotEmpty ||
      _perPage != 25;
}

class _ActivityLogCard extends StatelessWidget {
  const _ActivityLogCard({required this.log, required this.onOpen});

  final Map<String, dynamic> log;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final ipContext = _map(log['ip_context']);

    final ipType = _text(ipContext['type'], '');

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _formatDate(log['created_at']),
                      style: TextStyle(
                        color: palette.textMain,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(log['created_at']),
                      style: TextStyle(color: palette.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'View activity log',
                onPressed: onOpen,
                icon: const Icon(Icons.visibility_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Icon(Icons.person_outline, size: 16),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _text(log['actor_name'], 'System / Unknown'),
                  style: TextStyle(
                    color: palette.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _pretty(_text(log['actor_role'], 'No actor role')),
                style: TextStyle(color: palette.textMuted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            _text(log['event'], 'activity'),
            style: TextStyle(
              color: palette.accentText,
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          _CategoryBadge(
            label: _text(
              log['category_label'],
              _pretty(_text(log['category'], 'Activity')),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _text(log['description'], 'No description.'),
            style: TextStyle(
              color: palette.textSoft,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: <Widget>[
              Icon(Icons.language_rounded, size: 15, color: palette.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _text(log['ip_address'], '—'),
                  style: TextStyle(
                    color: palette.textMuted,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
              if (ipType == 'loopback') const _MiniBadge(label: 'LOCAL BRIDGE'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.textSoft,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear == null
              ? const Icon(Icons.calendar_month_outlined)
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
        child: Text(value.isEmpty ? 'Not set' : value),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.textSoft,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaginationCard extends StatelessWidget {
  const _PaginationCard({
    required this.page,
    required this.lastPage,
    required this.total,
    required this.perPage,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
  });

  final int page;
  final int lastPage;
  final int total;
  final int perPage;
  final VoidCallback? onFirst;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onLast;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          Text(
            'Page $page of ${lastPage < 1 ? 1 : lastPage} • $perPage rows per page • $total matching records',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton.outlined(
                tooltip: 'First page',
                onPressed: onFirst,
                icon: const Icon(Icons.first_page_rounded),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                tooltip: 'Previous page',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: 10),
              Container(
                constraints: const BoxConstraints(minWidth: 42),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$page',
                  style: TextStyle(
                    color: palette.accentText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Next page',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                tooltip: 'Last page',
                onPressed: onLast,
                icon: const Icon(Icons.last_page_rounded),
              ),
            ],
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.receipt_long_outlined, size: 42),
          const SizedBox(height: 12),
          Text(
            'No activity logs matched the selected filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textMain,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Clear the filters or choose a wider date range.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted),
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

List<String> _stringList(Object? value) {
  if (value is! List) {
    return <String>[];
  }

  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<int> _intList(Object? value, {required List<int> fallback}) {
  if (value is! List) {
    return fallback;
  }

  final result = value
      .map(_int)
      .where((item) => item > 0)
      .toList(growable: false);

  return result.isEmpty ? fallback : result;
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  return int.tryParse(value.toString());
}

String _text(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? fallback : text;
}

String _pretty(String value) {
  return value
      .replaceAll('.', ' ')
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _dateValue(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');

  final day = value.day.toString().padLeft(2, '0');

  return '${value.year}-$month-$day';
}

DateTime? _parseDate(Object? raw) {
  final text = raw?.toString().trim() ?? '';

  if (text.isEmpty) {
    return null;
  }

  return DateTime.tryParse(text)?.toLocal();
}

String _formatDate(Object? raw) {
  final value = _parseDate(raw);

  if (value == null) {
    return '—';
  }

  const months = <String>[
    '',
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

  return '${months[value.month]} ${value.day}, ${value.year}';
}

String _formatTime(Object? raw) {
  final value = _parseDate(raw);

  if (value == null) {
    return '—';
  }

  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;

  final minute = value.minute.toString().padLeft(2, '0');

  final second = value.second.toString().padLeft(2, '0');

  final suffix = value.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute:$second $suffix';
}
