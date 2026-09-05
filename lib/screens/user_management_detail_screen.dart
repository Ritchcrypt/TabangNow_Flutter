import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/tabangnow_theme.dart';
import '../services/user_management_service.dart';
import 'user_management_form_screen.dart';

class UserManagementDetailScreen extends StatefulWidget {
  const UserManagementDetailScreen({
    super.key,
    required this.service,
    required this.userId,
  });

  final UserManagementService service;
  final int userId;

  @override
  State<UserManagementDetailScreen> createState() =>
      _UserManagementDetailScreenState();
}

class _UserManagementDetailScreenState
    extends State<UserManagementDetailScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _presenceRefreshing = false;
  String? _error;

  static const Duration _presencePollInterval = Duration(seconds: 30);
  Timer? _presenceTimer;

  Map<String, dynamic> _user = <String, dynamic>{};

  Map<String, dynamic> _options = <String, dynamic>{};

  Map<String, dynamic> _permissions = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();

    _presenceTimer = Timer.periodic(
      _presencePollInterval,
      (_) => _refreshPresence(),
    );
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await widget.service.show(widget.userId);

      if (!mounted) {
        return;
      }

      setState(() {
        _user = _map(response['data']);

        _options = _map(response['options']);

        _permissions = _map(response['permissions']);

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

  Future<void> _refreshPresence() async {
    if (_presenceRefreshing ||
        !mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    _presenceRefreshing = true;

    try {
      final response = await widget.service.presence();

      if (!mounted) {
        return;
      }

      final users = _map(response['users']);
      final presence = _map(users[widget.userId.toString()]);

      if (presence.isEmpty) {
        return;
      }

      setState(() {
        _user = <String, dynamic>{
          ..._user,
          'online': presence['online'] == true,
          'last_seen_at': presence['last_seen_at'],
        };
      });
    } catch (_) {
    } finally {
      _presenceRefreshing = false;
    }
  }

  bool _can(String key) => _permissions[key] == true;

  Future<void> _edit() async {
    if (!_can('can_update')) {
      return;
    }

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => UserManagementFormScreen(
          service: widget.service,
          initialUser: _user,
          options: _options,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    _show(_text(result['message'], 'User account updated successfully.'));

    await _load();
  }

  Future<void> _activate() async {
    if (_busy || !_can('can_activate')) {
      return;
    }

    final confirmed = await _confirm(
      title: 'Activate account',
      message:
          'Activate this user account? The status will change to Active and the user will be allowed to access the system.',
      confirmLabel: 'Activate',
    );

    if (!confirmed) {
      return;
    }

    await _runAction(() => widget.service.activate(widget.userId));
  }

  Future<void> _deactivate() async {
    if (_busy || !_can('can_deactivate')) {
      return;
    }

    final confirmed = await _confirm(
      title: 'Deactivate account',
      message:
          'Deactivate this user account? The user will no longer be allowed to access the system until an administrator activates the account again. Existing sessions and mobile tokens will be revoked.',
      confirmLabel: 'Deactivate',
      destructive: true,
    );

    if (!confirmed) {
      return;
    }

    await _runAction(() => widget.service.deactivate(widget.userId));
  }

  Future<void> _resetPassword() async {
    if (_busy || !_can('can_reset_password')) {
      return;
    }

    final confirmed = await _confirm(
      title: 'Send password reset link',
      message:
          'Send a secure password reset link to ${_text(_user['email'], 'this user')}? No temporary password will be exposed in the app.',
      confirmLabel: 'Send Link',
    );

    if (!confirmed) {
      return;
    }

    await _runAction(
      () => widget.service.sendPasswordResetLink(widget.userId),
      reload: false,
    );
  }

  Future<void> _delete() async {
    if (_busy || !_can('can_delete')) {
      return;
    }

    final confirmed = await _confirm(
      title: 'Permanent Delete',
      message:
          'Permanently delete ${_text(_user['name'], 'this user')}? Account-specific sessions, tokens, notifications, Employee/Tanod links, and profile data will be removed. Historical system references are preserved through the Deleted User placeholder. This cannot be undone.',
      confirmLabel: 'Permanent Delete',
      destructive: true,
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final response = await widget.service.delete(widget.userId);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        _text(
          response['message'],
          'User was permanently deleted successfully.',
        ),
      );
    } catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
      });

      _show(exception.toString().replaceFirst('AuthException: ', ''));
    }
  }

  Future<void> _runAction(
    Future<Map<String, dynamic>> Function() action, {
    bool reload = true,
  }) async {
    setState(() {
      _busy = true;
    });

    try {
      final response = await action();

      if (!mounted) {
        return;
      }

      _show(_text(response['message'], 'User account action completed.'));

      if (reload) {
        await _load();
      }
    } catch (exception) {
      if (mounted) {
        _show(exception.toString().replaceFirst('AuthException: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: destructive
                      ? FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB91C1C),
                          foregroundColor: Colors.white,
                        )
                      : null,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(
        title: const Text('User Details'),
        actions: <Widget>[
          if (_can('can_update'))
            IconButton(
              tooltip: 'Edit user',
              onPressed: _busy ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_busy) const LinearProgressIndicator(minHeight: 2),
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
          const SizedBox(height: 100),
          const Icon(Icons.error_outline_rounded, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Try Again')),
        ],
      );
    }

    final palette = TabangNowTheme.of(context);

    final employee = _map(_user['employee']);

    final active = _user['is_active'] == true;

    final online = _user['online'] == true;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: <Widget>[
        _Surface(
          child: Column(
            children: <Widget>[
              _LargeUserAvatar(service: widget.service, user: _user),
              const SizedBox(height: 12),
              Text(
                _text(_user['name'], 'User'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textMain,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${_text(_user['role_label'], 'User')} account',
                style: TextStyle(color: palette.textMuted),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _StateBadge(
                    label: active ? 'Active' : 'Inactive',
                    semantic: active
                        ? _BadgeSemantic.success
                        : _BadgeSemantic.neutral,
                  ),
                  _StateBadge(
                    label: online ? 'Online' : 'Offline',
                    semantic: online
                        ? _BadgeSemantic.success
                        : _BadgeSemantic.neutral,
                  ),
                  _StateBadge(
                    label: _text(_user['role_label'], 'User'),
                    semantic: _BadgeSemantic.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SectionTitle(title: 'Account Information'),
              const SizedBox(height: 14),
              _InfoLine(label: 'Full Name', value: _text(_user['name'], '—')),
              _InfoLine(label: 'Email', value: _text(_user['email'], '—')),
              _InfoLine(
                label: 'Contact Number',
                value: _text(_user['contact_number'], '—'),
              ),
              _InfoLine(label: 'Address', value: _text(_user['address'], '—')),
              _InfoLine(
                label: 'Barangay',
                value: _text(_user['barangay_name'], '—'),
              ),
              _InfoLine(label: 'Role', value: _text(_user['role_label'], '—')),
              _InfoLine(
                label: 'Account Status',
                value: active ? 'Active' : 'Inactive',
              ),
              _InfoLine(
                label: 'Presence',
                value: online ? 'Online' : 'Offline',
              ),
              _InfoLine(
                label: 'Joined Date',
                value: _text(_user['joined_date'], '—'),
              ),
              _InfoLine(
                label: 'Last Seen',
                value: _formatDateTime(_user['last_seen_at']),
                isLast: true,
              ),
            ],
          ),
        ),
        if (employee.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SectionTitle(title: 'Employee Profile'),
                const SizedBox(height: 6),
                Text(
                  'Linked staff identity synchronized from User Management.',
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                _InfoLine(
                  label: 'Employee ID',
                  value: '#${_int(employee['id'])}',
                ),
                _InfoLine(
                  label: 'Type',
                  value: _pretty(employee['employee_type']),
                ),
                _InfoLine(
                  label: 'Position',
                  value: _text(employee['position'], '—'),
                ),
                _InfoLine(
                  label: 'Department',
                  value: _text(employee['department'], '—'),
                ),
                _InfoLine(
                  label: 'Employee Status',
                  value: employee['is_active'] == false ? 'Inactive' : 'Active',
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SectionTitle(title: 'Account Actions'),
              const SizedBox(height: 6),
              Text(
                _permissions['is_self'] == true
                    ? 'This is your current administrator account. Self-deactivation, self-demotion, and self-deletion remain blocked. The final active administrator cannot be demoted, deactivated, or deleted.'
                    : 'Security-sensitive changes are confirmed and rechecked by Laravel policies and transaction locks. The final active administrator cannot be demoted, deactivated, or deleted.',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              if (_can('can_update'))
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _edit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit User'),
                  ),
                ),
              if (active && _can('can_deactivate')) ...<Widget>[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _deactivate,
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('Deactivate Account'),
                  ),
                ),
              ],
              if (!active && _can('can_activate')) ...<Widget>[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _activate,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Activate Account'),
                  ),
                ),
              ],
              if (_can('can_reset_password')) ...<Widget>[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _resetPassword,
                    icon: const Icon(Icons.mark_email_read_outlined),
                    label: const Text('Send Password Reset Link'),
                  ),
                ),
              ],
              if (_can('can_delete')) ...<Widget>[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB91C1C),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Permanent Delete'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LargeUserAvatar extends StatelessWidget {
  const _LargeUserAvatar({required this.service, required this.user});

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
            return ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.memory(
                snapshot.data!,
                width: 112,
                height: 112,
                fit: BoxFit.cover,
              ),
            );
          }

          return _AvatarFallback(name: name);
        },
      );
    }

    return _AvatarFallback(name: name);
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      width: 112,
      height: 112,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: palette.accentText,
          fontSize: 42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

enum _BadgeSemantic { primary, success, neutral }

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.label, required this.semantic});

  final String label;
  final _BadgeSemantic semantic;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final pair = switch (semantic) {
      _BadgeSemantic.primary => (palette.accentSoft, palette.accentText),
      _BadgeSemantic.success => (
        palette.isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
        palette.isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
      ),
      _BadgeSemantic.neutral => (palette.surfaceMuted, palette.textSoft),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: pair.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: pair.$2,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: TabangNowTheme.of(context).textMain,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: palette.textSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
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

String _pretty(Object? value) {
  final text = _text(value, '—');

  if (text == '—') {
    return text;
  }

  return text
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _formatDateTime(Object? raw) {
  final text = raw?.toString().trim() ?? '';

  if (text.isEmpty) {
    return '—';
  }

  final parsed = DateTime.tryParse(text);

  if (parsed == null) {
    return text;
  }

  final value = parsed.toLocal();

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

  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;

  final minute = value.minute.toString().padLeft(2, '0');

  final suffix = value.hour >= 12 ? 'PM' : 'AM';

  return '${months[value.month]} ${value.day}, ${value.year} '
      '$hour:$minute $suffix';
}
