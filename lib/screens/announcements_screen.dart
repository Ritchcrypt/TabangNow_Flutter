import 'package:flutter/material.dart';

import '../core/app_capabilities.dart';
import '../core/app_role.dart';
import '../core/tabangnow_theme.dart';
import '../services/announcement_service.dart';
import '../services/auth_service.dart';
import 'announcement_create_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({
    super.key,
    required this.authService,
    required this.user,
  });

  final AuthService authService;
  final Map<String, dynamic> user;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  late final AnnouncementService _service;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  List<Map<String, dynamic>> _announcements = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _categories = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _priorities = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _audiences = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _barangays = <Map<String, dynamic>>[];

  int _currentPage = 1;
  int _lastPage = 1;

  AppRole get _role => AppRoleX.fromRaw(
    widget.user['role']?.toString().trim().toLowerCase() ?? '',
  );

  AppCapabilitySet get _capabilities => AppCapabilities.forRole(_role);

  bool get _canManage =>
      _capabilities.allows(AppCapability.manageAnnouncements);

  @override
  void initState() {
    super.initState();

    _service = AnnouncementService(authService: widget.authService);

    _load();
  }

  Future<void> _load({bool append = false}) async {
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

    final page = append ? _currentPage + 1 : 1;

    try {
      final response = await _service.index(page: page);

      if (!mounted) {
        return;
      }

      final incoming = _mapList(response['data']);
      final options = _map(response['options']);
      final pagination = _map(response['pagination']);

      setState(() {
        _announcements = append
            ? <Map<String, dynamic>>[..._announcements, ...incoming]
            : incoming;

        _categories = _mapList(options['categories']);

        _priorities = _mapList(options['priorities']);

        _audiences = _mapList(options['audiences']);

        final optionBarangays = _mapList(options['barangays']);

        if (optionBarangays.isNotEmpty) {
          _barangays = optionBarangays;
        }

        _currentPage = _int(pagination['current_page'], fallback: page);

        _lastPage = _int(pagination['last_page'], fallback: 1);

        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = exception.toString().replaceFirst('AuthException: ', '');
      });
    }
  }

  Future<void> _openCreate() async {
    if (!_canManage) {
      return;
    }

    var barangays = _barangays;

    if (barangays.isEmpty) {
      try {
        barangays = await _service.barangayOptions();

        if (!mounted) {
          return;
        }

        setState(() {
          _barangays = barangays;
        });
      } catch (exception) {
        if (mounted) {
          _show(
            exception.toString().replaceFirst('AuthException: ', ''),
          );
        }

        return;
      }
    }

    if (barangays.isEmpty) {
      _show(
        'No official Dao barangays are available for announcement targeting.',
      );
      return;
    }

    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => AnnouncementCreateScreen(
          service: _service,
          categories: _categories,
          priorities: _priorities,
          audiences: _audiences,
          barangays: barangays,
        ),
      ),
    );

    if (message == null || !mounted) {
      return;
    }

    _show(message);
    await _load();
  }

  Future<void> _toggle(Map<String, dynamic> announcement) async {
    if (!_canManage) {
      return;
    }

    final id = _int(announcement['id']);

    if (id <= 0) {
      return;
    }

    try {
      final response = await _service.toggle(id);

      if (!mounted) {
        return;
      }

      _show(response['message']?.toString() ?? 'Announcement updated.');

      await _load();
    } catch (exception) {
      if (mounted) {
        _show(exception.toString().replaceFirst('AuthException: ', ''));
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> announcement) async {
    if (!_canManage) {
      return;
    }

    final id = _int(announcement['id']);

    if (id <= 0) {
      return;
    }

    final title = _text(announcement['title'], 'this announcement');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: Text(
          'Delete "$title"? Its announcement/calamity notifications will also be removed.',
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
      ),
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
        response['message']?.toString() ?? 'Announcement deleted successfully.',
      );

      await _load();
    } catch (exception) {
      if (mounted) {
        _show(exception.toString().replaceFirst('AuthException: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: <Widget>[
          _Header(canManage: _canManage, onPost: _openCreate),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 100),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else if (_announcements.isEmpty)
            _EmptyCard(canManage: _canManage, onPost: _openCreate)
          else
            for (
              var index = 0;
              index < _announcements.length;
              index++
            ) ...<Widget>[
              _AnnouncementCard(
                announcement: _announcements[index],
                canManage: _canManage,
                onToggle: () => _toggle(_announcements[index]),
                onDelete: () => _delete(_announcements[index]),
              ),
              if (index != _announcements.length - 1)
                const SizedBox(height: 12),
            ],

          if (!_loading &&
              _error == null &&
              _currentPage < _lastPage) ...<Widget>[
            const SizedBox(height: 16),
            OutlinedButton.icon(
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
          ],

          const SizedBox(height: 10),
          if (!_canManage)
            Text(
              'Only active announcements intended for this account role are shown.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, fontSize: 11),
            ),
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

class _Header extends StatelessWidget {
  const _Header({required this.canManage, required this.onPost});

  final bool canManage;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Community Announcements',
            style: TextStyle(
              color: palette.textMain,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Advisories and emergency notifications',
            style: TextStyle(color: palette.textMuted),
          ),
          if (canManage) ...<Widget>[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPost,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Post Announcement'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.canManage,
    required this.onToggle,
    required this.onDelete,
  });

  final Map<String, dynamic> announcement;
  final bool canManage;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final category = _text(announcement['category'], 'general').toLowerCase();

    final priority = _text(announcement['priority'], 'normal').toLowerCase();

    final active = announcement['is_active'] == true;
    final calamity = announcement['calamity_mode'] == true;
    final weather = announcement['show_in_weather_feed'] == true;

    final poster = _map(announcement['poster']);

    final categoryColors = _categoryColors(palette, category);

    final priorityColors = _priorityColors(palette, priority);

    final cardBorder = calamity
        ? (palette.isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5))
        : priorityColors.$1;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
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
                  color: categoryColors.$1,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _categoryIcon(category),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _text(announcement['title'], 'Announcement'),
                  style: TextStyle(
                    color: palette.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  tooltip: 'Announcement actions',
                  onSelected: (action) {
                    if (action == 'toggle') {
                      onToggle();
                    }

                    if (action == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'toggle',
                      child: Row(
                        children: <Widget>[
                          Icon(
                            active
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          const SizedBox(width: 10),
                          Text(active ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFDC2626),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Delete',
                            style: TextStyle(color: Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              _Badge(
                label: _text(
                  announcement['category_label'],
                  _capitalize(category),
                ),
                background: categoryColors.$1,
                foreground: categoryColors.$2,
              ),
              _Badge(
                label: _text(
                  announcement['priority_label'],
                  _capitalize(priority),
                ),
                background: priorityColors.$1,
                foreground: priorityColors.$2,
              ),
              if (weather)
                _Badge(
                  label: 'Weather Feed',
                  background: palette.accentSoft,
                  foreground: palette.accentText,
                ),
              if (!active)
                _Badge(
                  label: 'Inactive',
                  background: palette.surfaceSoft,
                  foreground: palette.textSoft,
                ),
              if (calamity)
                _Badge(
                  label: 'Calamity Mode',
                  background: palette.isDark
                      ? const Color(0xFF7F1D1D)
                      : const Color(0xFFFEE2E2),
                  foreground: palette.isDark
                      ? const Color(0xFFFECACA)
                      : const Color(0xFFB91C1C),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            _text(announcement['content'], ''),
            style: TextStyle(color: palette.textSoft, height: 1.55),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              Text(
                'By ${_text(poster['name'], 'System')}',
                style: TextStyle(color: palette.textMuted, fontSize: 11),
              ),
              Text('•', style: TextStyle(color: palette.textFaint)),
              Text(
                _formatDateTime(
                  announcement['published_at'] ?? announcement['created_at'],
                ),
                style: TextStyle(color: palette.textMuted, fontSize: 11),
              ),
              Text('•', style: TextStyle(color: palette.textFaint)),
              Text(
                _text(announcement['audience_label'], 'All'),
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.canManage, required this.onPost});

  final bool canManage;
  final VoidCallback onPost;

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
          const Text('📢', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 12),
          Text(
            'No announcements yet',
            style: TextStyle(
              color: palette.textMain,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            canManage
                ? 'Post the first community announcement, advisory, or emergency notice.'
                : 'No community announcements, advisories, or emergency notices are available yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted),
          ),
          if (canManage) ...<Widget>[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onPost,
              child: const Text('Post Announcement'),
            ),
          ],
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

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }

  return '${value[0].toUpperCase()}${value.substring(1).replaceAll('_', ' ')}';
}

String _categoryIcon(String category) {
  return switch (category) {
    'emergency' || 'calamity' => '🚨',
    'advisory' => '📢',
    'health' => '🩺',
    _ => '📣',
  };
}

(Color, Color) _categoryColors(TabangNowTheme palette, String category) {
  return switch (category) {
    'emergency' || 'calamity' => (
      palette.isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
      palette.isDark ? const Color(0xFFFECACA) : const Color(0xFFB91C1C),
    ),
    'advisory' => (palette.accentSoft, palette.accentText),
    'community' => (
      palette.isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
      palette.isDark ? const Color(0xFFBBF7D0) : const Color(0xFF15803D),
    ),
    'health' => (
      palette.isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
      palette.isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
    ),
    _ => (palette.surfaceSoft, palette.textSoft),
  };
}

(Color, Color) _priorityColors(TabangNowTheme palette, String priority) {
  return switch (priority) {
    'important' => (palette.accentSoft, palette.accentText),
    'urgent' => (
      palette.isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5),
      palette.isDark ? const Color(0xFFFED7AA) : const Color(0xFFC2410C),
    ),
    'emergency' => (
      palette.isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
      palette.isDark ? const Color(0xFFFECACA) : const Color(0xFFB91C1C),
    ),
    _ => (palette.surfaceSoft, palette.textSoft),
  };
}

String _formatDateTime(Object? raw) {
  final text = raw?.toString().trim() ?? '';

  if (text.isEmpty) {
    return 'No date';
  }

  final parsed = DateTime.tryParse(text);

  if (parsed == null) {
    return text;
  }

  final value = parsed.toLocal();
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;

  final minute = value.minute.toString().padLeft(2, '0');

  final suffix = value.hour >= 12 ? 'PM' : 'AM';

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

  return '${months[value.month]} ${value.day}, ${value.year} '
      '$hour:$minute $suffix';
}
