import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/notification_center_service.dart';
import '../services/native_push_service.dart';

typedef GlobalNotificationOpenCallback =
    Future<void> Function(NotificationOpenTarget target);

class GlobalNotificationBell extends StatefulWidget {
  const GlobalNotificationBell({
    super.key,
    required this.authService,
    required this.onOpen,
  });

  final AuthService authService;
  final GlobalNotificationOpenCallback onOpen;

  @override
  State<GlobalNotificationBell> createState() => _GlobalNotificationBellState();
}

class _GlobalNotificationBellState extends State<GlobalNotificationBell> {
  static const Duration _pollInterval = Duration(seconds: 15);

  late final NotificationCenterService _service;

  Timer? _timer;
  StreamSubscription<NativePushEvent>? _pushSubscription;
  bool _loading = true;
  bool _requestRunning = false;
  bool _pulseInitialized = false;
  int _latestId = 0;
  int _latestEmergencyId = 0;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifications = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();

    _service = NotificationCenterService(authService: widget.authService);

    _pushSubscription = NativePushBridge.events.listen(_handleNativePushEvent);

    unawaited(
      _initialLoad().then((_) async {
        if (!mounted) {
          return;
        }

        final pendingId = NativePushBridge.takePendingOpenNotificationId();
        if (pendingId != null) {
          await _openNotificationById(pendingId);
        }
      }),
    );

    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pushSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleNativePushEvent(NativePushEvent event) async {
    if (event.openRequested) {
      final id = event.notificationId;
      NativePushBridge.clearPendingOpenNotificationId(id);

      if (id != null) {
        await _openNotificationById(id);
      }

      return;
    }

    if (event.notificationId != null && event.notificationId! > _latestId) {
      _latestId = event.notificationId!;
    }

    if (event.isEmergency &&
        event.notificationId != null &&
        event.notificationId! > _latestEmergencyId) {
      _latestEmergencyId = event.notificationId!;
    }

    await _loadBell();

    if (!mounted || event.notificationId == null) {
      return;
    }

    Map<String, dynamic>? notification;

    for (final item in _notifications) {
      if (_asInt(item['id']) == event.notificationId) {
        notification = item;
        break;
      }
    }

    if (notification == null) {
      return;
    }

    if (event.isEmergency) {
      await _playUrgentEmergencyFeedback();

      if (mounted) {
        _showEmergencyBanner(notification);
      }

      return;
    }

    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.lightImpact();

    if (mounted) {
      _showNotificationBanner(notification);
    }
  }

  Future<void> _initialLoad() async {
    await _loadBell();

    try {
      final response = await _service.pulse();
      final raw = response['data'];
      final data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      _latestId = _asInt(data['latest_notification_id']);
      _latestEmergencyId = _asInt(data['latest_emergency_notification_id']);
      _pulseInitialized = true;

      if (_notifications.isNotEmpty) {
        await _surfaceInitialUnread();
      }
    } catch (_) {
      // A temporary pulse failure must not break the bell. The next successful
      // poll establishes the cursors without replaying old notifications.
    }
  }

  Future<void> _surfaceInitialUnread() async {
    if (!mounted || _notifications.isEmpty) {
      return;
    }

    final latest = _notifications.first;
    final type = latest['type']?.toString().trim().toLowerCase() ?? '';

    if (type == 'mobile_emergency') {
      await _playUrgentEmergencyFeedback();

      if (mounted) {
        _showEmergencyBanner(latest);
      }

      return;
    }

    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.lightImpact();

    if (mounted) {
      _showNotificationBanner(latest, initialUnreadCount: _unreadCount);
    }
  }

  Future<void> _poll() async {
    if (_requestRunning) {
      return;
    }

    _requestRunning = true;

    try {
      final response = await _service.pulse();
      final raw = response['data'];
      final data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      final latest = _asInt(data['latest_notification_id']);
      final latestEmergency = _asInt(data['latest_emergency_notification_id']);

      if (!_pulseInitialized) {
        _latestId = latest;
        _latestEmergencyId = latestEmergency;
        _pulseInitialized = true;
        return;
      }

      final hasNewEmergency =
          latestEmergency > 0 && latestEmergency > _latestEmergencyId;
      final hasNewNotification = latest > 0 && latest > _latestId;

      if (hasNewEmergency) {
        _latestEmergencyId = latestEmergency;

        if (latest > _latestId) {
          _latestId = latest;
        }

        await _playUrgentEmergencyFeedback();
        await _loadBell();

        if (mounted) {
          _showEmergencyBanner(data['emergency_notification']);
        }

        return;
      }

      if (hasNewNotification) {
        _latestId = latest;

        await SystemSound.play(SystemSoundType.alert);
        await HapticFeedback.lightImpact();
        await _loadBell();

        if (mounted) {
          _showNotificationBanner(data['notification']);
        }
      }
    } catch (_) {
      // Keep polling resilient to temporary network failure.
    } finally {
      _requestRunning = false;
    }
  }

  Future<void> _playUrgentEmergencyFeedback() async {
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.mediumImpact();
  }

  void _showEmergencyBanner(Object? rawNotification) {
    if (!mounted) {
      return;
    }

    final notification = rawNotification is Map
        ? Map<String, dynamic>.from(rawNotification)
        : <String, dynamic>{};
    final message =
        (notification['message']?.toString().trim().isNotEmpty ?? false)
        ? notification['message'].toString().trim()
        : 'A new Distress Signal requires responder attention.';
    final id = _asInt(notification['id']);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          backgroundColor: const Color(0xFFB91C1C),
          content: Row(
            children: <Widget>[
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'URGENT DISTRESS SIGNAL\n$message',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          action: id > 0
              ? SnackBarAction(
                  label: 'OPEN',
                  textColor: Colors.white,
                  onPressed: () {
                    unawaited(_openNotification(notification));
                  },
                )
              : null,
        ),
      );
  }

  void _showNotificationBanner(
    Object? rawNotification, {
    int? initialUnreadCount,
  }) {
    if (!mounted) {
      return;
    }

    final notification = rawNotification is Map
        ? Map<String, dynamic>.from(rawNotification)
        : <String, dynamic>{};
    final title = notification['title']?.toString().trim().isNotEmpty == true
        ? notification['title'].toString().trim()
        : notification['type_label']?.toString().trim().isNotEmpty == true
        ? notification['type_label'].toString().trim()
        : 'TabangNow notification';
    final message =
        notification['message']?.toString().trim().isNotEmpty == true
        ? notification['message'].toString().trim()
        : 'A new update requires your attention.';
    final id = _asInt(notification['id']);
    final countPrefix = initialUnreadCount != null && initialUnreadCount > 1
        ? 'You have $initialUnreadCount unread notifications.\n'
        : '';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 7),
          backgroundColor: const Color(0xFF1D4ED8),
          content: Text(
            '$countPrefix$title\n$message',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          action: id > 0
              ? SnackBarAction(
                  label: 'OPEN',
                  textColor: Colors.white,
                  onPressed: () {
                    unawaited(_openNotification(notification));
                  },
                )
              : null,
        ),
      );
  }

  Future<void> _loadBell() async {
    try {
      final response = await _service.bell();
      final raw = response['data'];
      final data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      final rawNotifications = data['notifications'];
      final notifications = rawNotifications is List
          ? rawNotifications
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false)
          : <Map<String, dynamic>>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _unreadCount = _asInt(data['unread_count']);
        _notifications = notifications;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final id = _asInt(notification['id']);

    if (id <= 0) {
      return;
    }

    await _openNotificationById(id);
  }

  Future<void> _openNotificationById(int id) async {
    if (id <= 0) {
      return;
    }

    try {
      final target = await _service.open(id);

      await _loadBell();

      if (!mounted) {
        return;
      }

      await widget.onOpen(target);
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(exception.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to open the notification.')),
        );
    }
  }

  Future<void> _showNotifications() async {
    await _loadBell();

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return _NotificationSheet(
          unreadCount: _unreadCount,
          notifications: _notifications,
          onOpen: (notification) async {
            Navigator.of(sheetContext).pop();
            await _openNotification(notification);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 40,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _showNotifications,
                child: Tooltip(
                  message: 'Notifications',
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('🔔', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ),
            ),
            if (_unreadCount > 0)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Text(
                    _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet({
    required this.unreadCount,
    required this.notifications,
    required this.onOpen,
  });

  final int unreadCount;
  final List<Map<String, dynamic>> notifications;
  final Future<void> Function(Map<String, dynamic> notification) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Unread Notifications',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Latest updates for your account',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: notifications.isEmpty
                  ? const _EmptyNotifications()
                  : ListView.separated(
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: theme.dividerColor),
                      itemBuilder: (context, index) {
                        final item = notifications[index];

                        return InkWell(
                          onTap: () => onOpen(item),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    (item['type_label']?.toString() ??
                                            'Notification')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF1D4ED8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item['message']?.toString() ??
                                      'No notification message provided.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        item['age']?.toString() ?? 'No date',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Open →',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: const Text('🔔', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 12),
            const Text(
              'No unread notifications.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'New updates will appear here.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
