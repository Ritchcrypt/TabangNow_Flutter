import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_capabilities.dart';
import '../core/app_role.dart';
import '../core/tabangnow_theme.dart';
import '../services/auth_service.dart';
import '../services/user_management_service.dart';
import 'user_management_detail_screen.dart';
import 'user_management_form_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({
    super.key,
    required this.authService,
    required this.user,
  });

  final AuthService authService;
  final Map<String, dynamic> user;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late final UserManagementService _service;

  final _searchController = TextEditingController();

  bool _loading = true;
  bool _exporting = false;
  bool _presenceRefreshing = false;
  String? _error;

  static const Duration _presencePollInterval = Duration(seconds: 30);
  Timer? _presenceTimer;

  List<Map<String, dynamic>> _users = <Map<String, dynamic>>[];

  Map<String, dynamic> _summary = <String, dynamic>{};

  Map<String, dynamic> _options = <String, dynamic>{};

  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  int _perPage = 25;

  String _role = 'all';
  String _status = 'all';
  String _date = 'all';

  AppRole get _roleOfCurrentUser => AppRoleX.fromRaw(
    widget.user['role']?.toString().trim().toLowerCase() ?? '',
  );

  bool get _canManageUsers => AppCapabilities.forRole(
    _roleOfCurrentUser,
  ).allows(AppCapability.manageUsers);

  @override
  void initState() {
    super.initState();

    _service = UserManagementService(authService: widget.authService);

    _load();
    _startPresencePolling();
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    if (!_canManageUsers) {
      setState(() {
        _loading = false;
        _error = 'User Management is restricted to administrator accounts.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _service.index(
        page: page ?? _page,
        perPage: _perPage,
        search: _searchController.text,
        role: _role,
        status: _status,
        date: _date,
      );

      if (!mounted) {
        return;
      }

      final pagination = _map(response['pagination']);

      final filters = _map(response['filters']);

      setState(() {
        _users = _mapList(response['data']);

        _summary = _map(response['summary']);

        _options = _map(response['options']);

        _page = _int(pagination['current_page'], fallback: 1);

        _lastPage = _int(pagination['last_page'], fallback: 1);

        _total = _int(pagination['total']);

        _perPage = _int(filters['per_page'], fallback: _perPage);

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

  void _startPresencePolling() {
    _presenceTimer?.cancel();

    _presenceTimer = Timer.periodic(
      _presencePollInterval,
      (_) => _refreshPresence(),
    );
  }

  Future<void> _refreshPresence() async {
    if (!_canManageUsers ||
        _presenceRefreshing ||
        !mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    _presenceRefreshing = true;

    try {
      final response = await _service.presence();

      if (!mounted) {
        return;
      }

      final presenceByUser = _map(response['users']);
      final presenceSummary = _map(response['summary']);

      setState(() {
        _users = _users
            .map((user) {
              final id = _int(user['id']);
              final presence = _map(presenceByUser[id.toString()]);

              if (id <= 0 || presence.isEmpty) {
                return user;
              }

              return <String, dynamic>{
                ...user,
                'online': presence['online'] == true,
                'last_seen_at': presence['last_seen_at'],
              };
            })
            .toList(growable: false);

        if (presenceSummary.isNotEmpty) {
          _summary = <String, dynamic>{
            ..._summary,
            'online': _int(presenceSummary['online']),
            'offline': _int(presenceSummary['offline']),
          };
        }
      });
    } catch (_) {
      // Presence polling is best-effort and must not replace the loaded list
      // with an error screen if the network briefly drops.
    } finally {
      _presenceRefreshing = false;
    }
  }

  Future<void> _search() async {
    _page = 1;
    await _load(page: 1);
  }

  Future<void> _resetFilters() async {
    _searchController.clear();

    setState(() {
      _role = 'all';
      _status = 'all';
      _date = 'all';
      _page = 1;
    });

    await _load(page: 1);
  }

  Future<void> _openFilters() async {
    var role = _role;
    var status = _status;
    var date = _date;
    var perPage = _perPage;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TabangNowTheme.of(context).surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final palette = TabangNowTheme.of(context);

            final roles = _mapList(_options['roles']);

            final presence = _mapList(_options['presence']);

            final dates = _mapList(_options['dates']);

            final perPageOptions =
                (_options['per_page'] is List
                        ? List<Object?>.from(_options['per_page'] as List)
                        : const <Object?>[10, 25, 50, 100, 250])
                    .map(_int)
                    .where((value) => value > 0)
                    .toList(growable: false);

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
                        'User Filters',
                        style: TextStyle(
                          color: palette.textMain,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Filter by role, online presence, joined date, and rows per page.',
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: 'all',
                            child: Text('All Roles'),
                          ),
                          ...roles.map(
                            (option) => DropdownMenuItem<String>(
                              value: _text(option['value'], ''),
                              child: Text(_text(option['label'], 'Role')),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setSheetState(() {
                            role = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(
                          labelText: 'Presence',
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: 'all',
                            child: Text('All Presence'),
                          ),
                          ...presence.map(
                            (option) => DropdownMenuItem<String>(
                              value: _text(option['value'], ''),
                              child: Text(_text(option['label'], 'Presence')),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setSheetState(() {
                            status = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: date,
                        decoration: const InputDecoration(
                          labelText: 'Joined Date',
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: 'all',
                            child: Text('All Dates'),
                          ),
                          ...dates.map(
                            (option) => DropdownMenuItem<String>(
                              value: _text(option['value'], ''),
                              child: Text(_text(option['label'], 'Date')),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setSheetState(() {
                            date = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: perPage,
                        decoration: const InputDecoration(
                          labelText: 'Rows per page',
                        ),
                        items:
                            (perPageOptions.isEmpty
                                    ? const <int>[10, 25, 50, 100, 250]
                                    : perPageOptions)
                                .map(
                                  (value) => DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(value.toString()),
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
                                    'role': role,
                                    'status': status,
                                    'date': date,
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
      _role = _text(result['role'], 'all');
      _status = _text(result['status'], 'all');
      _date = _text(result['date'], 'all');
      _perPage = _int(result['per_page'], fallback: 25);
      _page = 1;
    });

    await _load(page: 1);
  }

  Future<void> _addUser() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) =>
            UserManagementFormScreen(service: _service, options: _options),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    _show(_text(result['message'], 'User account created successfully.'));

    await _load(page: 1);
  }

  Future<void> _openUser(int userId) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) =>
            UserManagementDetailScreen(service: _service, userId: userId),
      ),
    );

    if (!mounted) {
      return;
    }

    if (message != null) {
      _show(message);
    }

    await _load(page: _page);
  }

  Future<void> _export() async {
    if (_exporting) {
      return;
    }

    setState(() {
      _exporting = true;
    });

    try {
      final export = await _service.export(
        search: _searchController.text,
        role: _role,
        status: _status,
        date: _date,
      );

      final documents = await getApplicationDocumentsDirectory();

      final directory = Directory(
        '${documents.path}${Platform.pathSeparator}TabangNow Exports',
      );

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = File(
        '${directory.path}${Platform.pathSeparator}${export.fileName}',
      );

      await file.writeAsBytes(export.bytes, flush: true);

      if (!mounted) {
        return;
      }

      _show('User export saved as ${export.fileName}. Opening it now.');

      final result = await OpenFilex.open(file.path);

      if (result.type != ResultType.done && mounted) {
        _show(
          result.message.isNotEmpty
              ? result.message
              : 'The CSV was saved, but no compatible app could open it.',
        );
      }
    } catch (exception) {
      if (mounted) {
        _show(exception.toString().replaceFirst('AuthException: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    if (!_canManageUsers) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const <Widget>[
          SizedBox(height: 100),
          Icon(Icons.lock_outline_rounded, size: 48),
          SizedBox(height: 14),
          Text(
            'User Management is restricted to administrator accounts.',
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Users',
                      style: TextStyle(
                        color: palette.textMain,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Manage admin, official, tanod, and resident accounts.',
                      style: TextStyle(color: palette.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Export',
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: 'Add User',
                onPressed: _loading ? null : _addUser,
                icon: const Icon(Icons.person_add_alt_1_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SummaryGrid(summary: _summary),
          const SizedBox(height: 16),
          _Surface(
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search users',
                    hintText: 'Search name, email, contact, address...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              _search();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _search,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Search'),
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
                      tooltip: 'Reset filters',
                      onPressed: _loading ? null : _resetFilters,
                      icon: const Icon(Icons.restart_alt_rounded),
                    ),
                  ],
                ),
                if (_hasFilters) ...<Widget>[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        if (_role != 'all')
                          _FilterChip(label: 'Role: ${_pretty(_role)}'),
                        if (_status != 'all')
                          _FilterChip(label: 'Presence: ${_pretty(_status)}'),
                        if (_date != 'all')
                          _FilterChip(label: 'Date: ${_pretty(_date)}'),
                        if (_perPage != 10)
                          _FilterChip(label: 'Rows: $_perPage'),
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
          else if (_users.isEmpty)
            const _EmptyCard()
          else
            for (var index = 0; index < _users.length; index++) ...<Widget>[
              _UserCard(
                service: _service,
                user: _users[index],
                onOpen: () => _openUser(_int(_users[index]['id'])),
              ),
              if (index != _users.length - 1) const SizedBox(height: 10),
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
      _role != 'all' || _status != 'all' || _date != 'all' || _perPage != 10;

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final Map<String, dynamic> summary;

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
              label: 'Total Users',
              value: _int(summary['total']),
              icon: Icons.groups_rounded,
            ),
            _SummaryCard(
              width: width,
              label: 'Online',
              value: _int(summary['online']),
              icon: Icons.circle_rounded,
            ),
            _SummaryCard(
              width: width,
              label: 'Offline',
              value: _int(summary['offline']),
              icon: Icons.cloud_off_outlined,
            ),
            _SummaryCard(
              width: width,
              label: 'Staff',
              value: _int(summary['staff']),
              icon: Icons.badge_outlined,
            ),
            _SummaryCard(
              width: width,
              label: 'Residents',
              value: _int(summary['residents']),
              icon: Icons.home_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: palette.accentText),
          const SizedBox(height: 9),
          Text(
            value.toString(),
            style: TextStyle(
              color: palette.textMain,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.service,
    required this.user,
    required this.onOpen,
  });

  final UserManagementService service;
  final Map<String, dynamic> user;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SmallAvatar(service: service, user: user),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _text(user['name'], 'User'),
                        style: TextStyle(
                          color: palette.textMain,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_text(user['role_label'], 'User')} account',
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _PresenceBadge(online: user['online'] == true),
              ],
            ),
            const SizedBox(height: 13),
            _CardLine(
              icon: Icons.email_outlined,
              value: _text(user['email'], '—'),
            ),
            const SizedBox(height: 7),
            _CardLine(
              icon: Icons.phone_outlined,
              value: _text(user['contact_number'], '—'),
            ),
            const SizedBox(height: 7),
            _CardLine(
              icon: Icons.home_outlined,
              value: _text(user['address'], '—'),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _RoleBadge(label: _text(user['role_label'], 'User')),
                const Spacer(),
                Text(
                  _text(user['joined_date'], '—'),
                  style: TextStyle(color: palette.textMuted, fontSize: 10),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({required this.service, required this.user});

  final UserManagementService service;
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final name = _text(user['name'], 'User');

    if (user['has_profile_photo'] == true && _int(user['id']) > 0) {
      return FutureBuilder<Uint8List>(
        future: service.profilePhotoBytes(_int(user['id'])),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ClipOval(
              child: Image.memory(
                snapshot.data!,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
              ),
            );
          }

          return _InitialCircle(name: name);
        },
      );
    }

    return _InitialCircle(name: name);
  }
}

class _InitialCircle extends StatelessWidget {
  const _InitialCircle({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.accentSoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: palette.accentText,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Row(
      children: <Widget>[
        Icon(icon, size: 15, color: palette.textMuted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textSoft, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _PresenceBadge extends StatelessWidget {
  const _PresenceBadge({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final background = online
        ? (palette.isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
        : palette.surfaceMuted;

    final foreground = online
        ? (palette.isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857))
        : palette.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            online ? 'Online' : 'Offline',
            style: TextStyle(
              color: foreground,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.accentText,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

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
            'Page $page of ${lastPage < 1 ? 1 : lastPage} • $perPage rows per page • $total total rows',
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
          const Icon(Icons.person_search_outlined, size: 42),
          const SizedBox(height: 12),
          Text(
            'No users found',
            style: TextStyle(
              color: palette.textMain,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Add users or adjust the current filters.',
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

int _int(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _text(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? fallback : text;
}

String _pretty(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
