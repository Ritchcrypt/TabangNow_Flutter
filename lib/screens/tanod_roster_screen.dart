import 'package:flutter/material.dart';

import '../core/tabangnow_theme.dart';
import '../services/auth_service.dart';
import '../services/tanod_roster_service.dart';

class TanodRosterScreen extends StatefulWidget {
  const TanodRosterScreen({
    super.key,
    required this.authService,
    required this.user,
  });

  final AuthService authService;
  final Map<String, dynamic> user;

  @override
  State<TanodRosterScreen> createState() => _TanodRosterScreenState();
}

class _TanodRosterScreenState extends State<TanodRosterScreen> {
  late final TanodRosterService _service;

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  List<Map<String, dynamic>> _tanods = <Map<String, dynamic>>[];

  Map<String, dynamic> _summary = <String, dynamic>{};

  Map<String, dynamic> _permissions = <String, dynamic>{};

  List<Map<String, dynamic>> _shiftOptions = <Map<String, dynamic>>[];

  List<Map<String, dynamic>> _statusOptions = <Map<String, dynamic>>[];

  int _currentPage = 1;
  int _lastPage = 1;

  String get _role =>
      widget.user['role']?.toString().trim().toLowerCase() ?? '';

  bool get _allowed =>
      _role == 'admin' || _role == 'official' || _role == 'dao';

  bool get _canCreate => _permissions['can_create'] == true;

  bool get _canUpdate => _permissions['can_update'] == true;

  bool get _canDelete => _permissions['can_delete'] == true;

  int get _totalTanods => _toIntStatic(_summary['total_tanods']) ?? 0;

  int get _onDutyCount => _toIntStatic(_summary['on_duty_count']) ?? 0;

  @override
  void initState() {
    super.initState();

    _service = TanodRosterService(authService: widget.authService);

    if (_allowed) {
      _load();
    } else {
      _loading = false;
      _error = 'Tanod Roster is available only to Admin and Official accounts.';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (!_allowed) {
      return;
    }

    if (append) {
      if (_loadingMore || _currentPage >= _lastPage) {
        return;
      }

      setState(() {
        _loadingMore = true;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final requestPage = append ? _currentPage + 1 : 1;

    try {
      final response = await _service.roster(
        search: _searchController.text,
        page: requestPage,
      );

      if (!mounted) {
        return;
      }

      final incoming = _mapList(response['data']);

      final options = _map(response['options']);

      final pagination = _map(response['pagination']);

      setState(() {
        _tanods = append
            ? <Map<String, dynamic>>[..._tanods, ...incoming]
            : incoming;

        _summary = _map(response['summary']);

        _permissions = _map(response['permissions']);

        final shifts = _mapList(options['shifts']);

        final statuses = _mapList(options['statuses']);

        if (shifts.isNotEmpty) {
          _shiftOptions = shifts;
        }

        if (statuses.isNotEmpty) {
          _statusOptions = statuses;
        }

        _currentPage = _toIntStatic(pagination['current_page']) ?? requestPage;

        _lastPage = _toIntStatic(pagination['last_page']) ?? 1;

        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = exception.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Unable to load the Tanod Roster.';
      });
    }
  }

  Future<void> _resetSearch() async {
    _searchController.clear();
    await _load();
  }

  Future<void> _openAddTanod() async {
    if (!_canCreate) {
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _TanodFormSheet(
        service: _service,
        shiftOptions: _shiftOptions,
        statusOptions: _statusOptions,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    _show(result);
    await _load();
  }

  Future<void> _openEditTanod(Map<String, dynamic> tanod) async {
    if (!_canUpdate) {
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _TanodFormSheet(
        service: _service,
        shiftOptions: _shiftOptions,
        statusOptions: _statusOptions,
        initial: tanod,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    _show(result);
    await _load();
  }

  Future<void> _deleteTanod(Map<String, dynamic> tanod) async {
    if (!_canDelete) {
      return;
    }

    final id = _toIntStatic(tanod['id']);

    if (id == null) {
      return;
    }

    final name = tanod['full_name']?.toString().trim().isNotEmpty == true
        ? tanod['full_name'].toString().trim()
        : 'this tanod member';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Tanod Member'),
          content: Text(
            'Delete "$name"? This permanently removes the roster profile, linked employee record, and tanod user account. This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final response = await _service.delete(id);

      if (!mounted) {
        return;
      }

      _show(
        response['message']?.toString() ?? 'Tanod member deleted successfully.',
      );

      await _load();
    } on AuthException catch (exception) {
      _show(exception.message);
    } catch (_) {
      _show('Unable to delete the tanod member.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    if (!_allowed) {
      return _AccessDeniedCard(
        message: _error ?? 'Tanod Roster is not available for this account.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: <Widget>[
          _RosterHeader(
            onDutyCount: _onDutyCount,
            totalTanods: _totalTanods,
            canCreate: _canCreate,
            onCreate: _openAddTanod,
          ),
          const SizedBox(height: 16),

          _SearchPanel(
            controller: _searchController,
            onSearch: _load,
            onReset: _resetSearch,
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 90),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else if (_tanods.isEmpty)
            const _EmptyRosterCard()
          else ...<Widget>[
            for (var index = 0; index < _tanods.length; index++) ...<Widget>[
              _TanodCard(
                tanod: _tanods[index],
                canUpdate: _canUpdate,
                canDelete: _canDelete,
                onEdit: () => _openEditTanod(_tanods[index]),
                onDelete: () => _deleteTanod(_tanods[index]),
              ),
              if (index != _tanods.length - 1) const SizedBox(height: 12),
            ],

            if (_currentPage < _lastPage) ...<Widget>[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loadingMore ? null : () => _load(append: true),
                  icon: _loadingMore
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(_loadingMore ? 'Loading...' : 'Load More'),
                ),
              ),
            ],
          ],

          const SizedBox(height: 8),
          Text(
            'Ranking is based only on accepted Tanod Task responses.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _show(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RosterHeader extends StatelessWidget {
  const _RosterHeader({
    required this.onDutyCount,
    required this.totalTanods,
    required this.canCreate,
    required this.onCreate,
  });

  final int onDutyCount;
  final int totalTanods;
  final bool canCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12020617),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Tanod Roster',
            style: TextStyle(
              color: palette.textMain,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$onDutyCount on duty • $totalTanods total',
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (canCreate) ...<Widget>[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF172554),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Add Tanod',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.onSearch,
    required this.onReset,
  });

  final TextEditingController controller;
  final Future<void> Function() onSearch;
  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Search Roster',
            style: TextStyle(
              color: palette.textMain,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: 'Name, contact, purok, shift, or status...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: onSearch,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TanodCard extends StatelessWidget {
  const _TanodCard({
    required this.tanod,
    required this.canUpdate,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> tanod;
  final bool canUpdate;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final rank = _toIntStatic(tanod['rank']) ?? 0;

    final responses = _toIntStatic(tanod['accepted_responses_count']) ?? 0;

    final name = tanod['full_name']?.toString() ?? 'Unnamed Tanod';

    final contact = _display(tanod['contact_number']);

    final purok = _display(tanod['purok_assignment']);

    final shift = tanod['shift_label']?.toString().trim().isNotEmpty == true
        ? tanod['shift_label'].toString().trim()
        : 'Day';

    final status = tanod['status']?.toString().trim().toLowerCase() ?? 'active';

    final statusLabel =
        tanod['status_label']?.toString().trim().isNotEmpty == true
        ? tanod['status_label'].toString().trim()
        : _humanize(status);

    final dateAppointed = _display(tanod['date_appointed']);
    final autoDutyEnabled = tanod['auto_duty_enabled'] == true;
    final scheduledDutyLabel = _display(tanod['scheduled_duty_label']);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D020617),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.surfaceSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🛡', style: TextStyle(fontSize: 21)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surfaceSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '#$rank',
                              style: TextStyle(
                                color: palette.textSoft,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          _ResponsesBadge(responses: responses),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: TextStyle(
                          color: palette.textMain,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (contact != '—') ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          '📞 $contact',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: status, label: statusLabel),
              ],
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: palette.border),
            const SizedBox(height: 14),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _InfoChip(label: 'Purok', value: purok),
                _InfoChip(label: 'Shift', value: shift),
                _InfoChip(label: 'Appointed', value: dateAppointed),
                if (autoDutyEnabled)
                  _InfoChip(
                    label: 'Auto Duty',
                    value: scheduledDutyLabel == '—'
                        ? 'Scheduled'
                        : scheduledDutyLabel,
                  ),
              ],
            ),

            if (canUpdate || canDelete) ...<Widget>[
              const SizedBox(height: 16),
              Divider(height: 1, color: palette.border),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (canUpdate)
                    _ActionIconButton(
                      tooltip: 'Edit tanod',
                      icon: Icons.edit_rounded,
                      onPressed: onEdit,
                    ),
                  if (canUpdate && canDelete) const SizedBox(width: 8),
                  if (canDelete)
                    _ActionIconButton(
                      tooltip: 'Delete tanod',
                      icon: Icons.delete_outline_rounded,
                      destructive: true,
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResponsesBadge extends StatelessWidget {
  const _ResponsesBadge({required this.responses});

  final int responses;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Tooltip(
      message: 'Accepted task responses',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: palette.accentSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.accent.withValues(alpha: 0.20)),
        ),
        child: Text(
          '$responses responses',
          style: TextStyle(
            color: palette.accentText,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final background = switch (status) {
      'on_duty' =>
        palette.isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
      'off_duty' => palette.surfaceSoft,
      _ => palette.isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
    };

    final foreground = switch (status) {
      'on_duty' =>
        palette.isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1D4ED8),
      'off_duty' => palette.textSoft,
      _ => palette.isDark ? const Color(0xFFBBF7D0) : const Color(0xFF15803D),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 95),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
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
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: palette.textMain,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final foreground = destructive ? const Color(0xFFDC2626) : palette.accent;

    return SizedBox(
      width: 42,
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: foreground,
          side: BorderSide(color: foreground.withValues(alpha: 0.30)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Tooltip(message: tooltip, child: Icon(icon, size: 20)),
      ),
    );
  }
}

class _TanodFormSheet extends StatefulWidget {
  const _TanodFormSheet({
    required this.service,
    required this.shiftOptions,
    required this.statusOptions,
    this.initial,
  });

  final TanodRosterService service;
  final List<Map<String, dynamic>> shiftOptions;
  final List<Map<String, dynamic>> statusOptions;
  final Map<String, dynamic>? initial;

  bool get editing => initial != null;

  @override
  State<_TanodFormSheet> createState() => _TanodFormSheetState();
}

class _TanodFormSheetState extends State<_TanodFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _emailController;
  late final TextEditingController _purokController;
  late final TextEditingController _dateController;
  late final TextEditingController _notesController;

  bool _busy = false;
  bool _autoDutyEnabled = false;
  late String _shift;
  late String _status;

  @override
  void initState() {
    super.initState();

    final initial = widget.initial ?? <String, dynamic>{};

    _nameController = TextEditingController(
      text: initial['full_name']?.toString() ?? '',
    );

    _contactController = TextEditingController(
      text: initial['contact_number']?.toString() ?? '',
    );

    _emailController = TextEditingController(
      text: initial['email']?.toString() ?? '',
    );

    _purokController = TextEditingController(
      text: initial['purok_assignment']?.toString() ?? '',
    );

    _dateController = TextEditingController(
      text: initial['date_appointed']?.toString() ?? '',
    );

    _notesController = TextEditingController(
      text: initial['notes']?.toString() ?? '',
    );

    _shift = _safeOptionValue(
      initial['shift']?.toString(),
      widget.shiftOptions,
      fallback: 'day',
    );

    _status = _safeOptionValue(
      initial['status']?.toString(),
      widget.statusOptions,
      fallback: 'active',
    );

    _autoDutyEnabled = initial['auto_duty_enabled'] == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _purokController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initialDate = DateTime.now();

    final current = DateTime.tryParse(_dateController.text.trim());

    if (current != null) {
      initialDate = current;
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );

    if (selected == null || !mounted) {
      return;
    }

    final year = selected.year.toString().padLeft(4, '0');

    final month = selected.month.toString().padLeft(2, '0');

    final day = selected.day.toString().padLeft(2, '0');

    setState(() {
      _dateController.text = '$year-$month-$day';
    });
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      late final Map<String, dynamic> response;

      if (widget.editing) {
        final id = _toIntStatic(widget.initial?['id']);

        if (id == null) {
          throw const AuthException('Tanod roster record is invalid.');
        }

        response = await widget.service.update(
          tanodId: id,
          fullName: _nameController.text,
          contactNumber: _contactController.text,
          email: _emailController.text,
          purokAssignment: _purokController.text,
          dateAppointed: _dateController.text,
          shift: _shift,
          status: _status,
          autoDutyEnabled: _autoDutyEnabled,
          notes: _notesController.text,
        );
      } else {
        response = await widget.service.create(
          fullName: _nameController.text,
          contactNumber: _contactController.text,
          email: _emailController.text,
          purokAssignment: _purokController.text,
          dateAppointed: _dateController.text,
          shift: _shift,
          status: _status,
          autoDutyEnabled: _autoDutyEnabled,
          notes: _notesController.text,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        response['message']?.toString() ??
            (widget.editing
                ? 'Tanod member updated successfully.'
                : 'Tanod member added successfully.'),
      );
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(exception.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to save the tanod member.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: palette.surface,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 22 + bottomInset),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.editing ? 'Edit Tanod' : 'Add New Tanod Member',
                      style: TextStyle(
                        color: palette.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'Full name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Full name is required.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  hintText: '09XXXXXXXXX',
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'email@example.com',
                  helperText: widget.editing
                      ? null
                      : 'Leave blank to auto-generate a local tanod email.',
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _purokController,
                decoration: const InputDecoration(
                  labelText: 'Purok Assignment',
                  hintText: 'Purok 1',
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: _pickDate,
                decoration: InputDecoration(
                  labelText: 'Date Appointed / Duty Start',
                  hintText: 'YYYY-MM-DD',
                  helperText:
                      'Future dates are allowed. Auto duty uses this date plus the selected shift start time.',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (_dateController.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear date',
                          onPressed: () {
                            setState(() {
                              _dateController.clear();
                            });
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                      IconButton(
                        tooltip: 'Choose date',
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month_rounded),
                      ),
                    ],
                  ),
                ),
                validator: (_) {
                  if (_autoDutyEnabled && _dateController.text.trim().isEmpty) {
                    return 'Choose a duty start date when auto activation is enabled.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _shift,
                decoration: const InputDecoration(labelText: 'Shift'),
                items: _optionItems(
                  widget.shiftOptions,
                  fallback: const <String, String>{
                    'day': 'Day',
                    'afternoon': 'Afternoon',
                    'night': 'Night',
                    'floating': 'Floating',
                  },
                ),
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _shift = value;
                        });
                      },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: _optionItems(
                  widget.statusOptions,
                  fallback: const <String, String>{
                    'active': 'Active',
                    'on_duty': 'On Duty',
                    'off_duty': 'Off Duty',
                  },
                ),
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _status = value;
                        });
                      },
              ),
              const SizedBox(height: 12),

              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _autoDutyEnabled,
                onChanged: _busy
                    ? null
                    : (value) {
                        setState(() {
                          _autoDutyEnabled = value;
                        });
                      },
                title: const Text('Auto activate On Duty'),
                subtitle: const Text(
                  'At the selected date and shift start, status changes to On Duty once. You can still edit status, shift, date, or disable this schedule.',
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _notesController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Additional notes...',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 20),
              Divider(color: palette.border),
              const SizedBox(height: 12),

              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.editing ? 'Update Tanod' : 'Add Tanod'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _optionItems(
    List<Map<String, dynamic>> options, {
    required Map<String, String> fallback,
  }) {
    final rows = options.isNotEmpty
        ? options
        : fallback.entries
              .map(
                (entry) => <String, dynamic>{
                  'value': entry.key,
                  'label': entry.value,
                },
              )
              .toList();

    return rows
        .map(
          (row) => DropdownMenuItem<String>(
            value: row['value']?.toString(),
            child: Text(
              row['label']?.toString() ?? row['value']?.toString() ?? '',
            ),
          ),
        )
        .where((item) => item.value != null)
        .toList(growable: false);
  }

  String _safeOptionValue(
    String? requested,
    List<Map<String, dynamic>> options, {
    required String fallback,
  }) {
    final normalized = requested?.trim() ?? '';

    final allowed = options
        .map((item) => item['value']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();

    if (allowed.isEmpty) {
      return normalized.isNotEmpty ? normalized : fallback;
    }

    if (normalized.isNotEmpty && allowed.contains(normalized)) {
      return normalized;
    }

    if (allowed.contains(fallback)) {
      return fallback;
    }

    return allowed.first;
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSoft),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

class _AccessDeniedCard extends StatelessWidget {
  const _AccessDeniedCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        const SizedBox(height: 100),
        Icon(Icons.lock_outline_rounded, size: 46, color: palette.textMuted),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyRosterCard extends StatelessWidget {
  const _EmptyRosterCard();

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 42),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          Text('👥', style: const TextStyle(fontSize: 34)),
          const SizedBox(height: 12),
          Text(
            'No tanod members found.',
            style: TextStyle(
              color: palette.textMain,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Add your first tanod member to start building the roster.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
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

int? _toIntStatic(Object? value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '');
}

String _display(Object? value) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? '—' : text;
}

String _humanize(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
