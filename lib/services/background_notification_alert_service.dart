import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

class TabangNowNotificationSettings {
  const TabangNowNotificationSettings({
    required this.notificationsEnabled,
    required this.channelFound,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.hasVibrator,
  });

  final bool notificationsEnabled;
  final bool channelFound;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool hasVibrator;
}

enum TabangNowAlertTier { critical, moderate, low, silent }

class TabangNowNotificationAlert {
  TabangNowNotificationAlert._();

  // Preserve the already-working v4 emergency channel and persistent alert ID.
  static const int persistentAlertId = 150015;
  static const String channelId = 'tabangnow_notifications_v4';
  static const String channelName = 'TabangNow Notifications';
  static const String channelDescription =
      'TabangNow notifications with enhanced sound and vibration';

  static const String moderateChannelId = 'tabangnow_moderate_v1';
  static const String moderateChannelName = 'Moderate Alerts';
  static const String moderateChannelDescription =
      'Important TabangNow alerts requiring attention';

  static const String lowChannelId = 'tabangnow_low_v1';
  static const String lowChannelName = 'Low Priority Updates';
  static const String lowChannelDescription =
      'Routine TabangNow status and informational updates';

  static const String silentChannelId = 'tabangnow_silent_v1';
  static const String silentChannelName = 'Silent Updates';
  static const String silentChannelDescription =
      'TabangNow notifications without sound or vibration';

  // Non-critical alerts wait briefly so a higher tier arriving in the same
  // burst can claim the audible slot first. This avoids Code Red, Moderate,
  // and Low sounds stacking on top of each other.
  static const Duration _moderateCoalesceDelay = Duration(milliseconds: 450);
  static const Duration _lowCoalesceDelay = Duration(milliseconds: 700);
  static const Duration _moderateCooldown = Duration(seconds: 8);
  static const Duration _lowCooldown = Duration(seconds: 5);
  static const Duration _minimumAudibleGap = Duration(seconds: 2);
  static const Duration _criticalStateGrace = Duration(seconds: 5);
  static const Duration _criticalStateMaxAge = Duration(hours: 24);

  static const String _arbiterStateFileName =
      'tabangnow_notification_alert_arbiter_v1.json';
  static const String _arbiterLockFileName =
      'tabangnow_notification_alert_arbiter_v1.lock';

  static final Int64List _criticalVibrationPattern = Int64List.fromList(<int>[
    0,
    850,
    250,
    850,
    250,
    1200,
  ]);

  static final Int64List _moderateVibrationPattern = Int64List.fromList(<int>[
    0,
    250,
    120,
    350,
  ]);

  static final Int64List _lowVibrationPattern = Int64List.fromList(<int>[
    0,
    120,
  ]);

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _mainInitialized = false;
  static bool _backgroundInitialized = false;
  static bool _channelsEnsured = false;

  // Used only if persistent arbiter storage is unexpectedly unavailable.
  // The normal path is the OS-locked file below, which coordinates isolates.
  static bool _fallbackCriticalActive = false;
  static int _fallbackLastAudibleAtMs = 0;
  static String _fallbackLastAudibleTier = '';

  static Future<Map<String, dynamic>?> initializeMain({
    required void Function(Map<String, dynamic> data) onOpened,
  }) async {
    if (!_mainInitialized) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final data = decodePayload(response.payload);
          if (data != null) {
            onOpened(data);
          }
        },
      );
      _mainInitialized = true;
    }

    await _ensureChannels();

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp != true) {
      return null;
    }

    return decodePayload(launchDetails?.notificationResponse?.payload);
  }

  @pragma('vm:entry-point')
  static Future<void> initializeBackground() async {
    if (!_backgroundInitialized) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _backgroundInitialized = true;
    }

    await _ensureChannels();
  }

  static Future<void> _ensureChannels() async {
    if (_channelsEnsured) {
      return;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) {
      return;
    }

    // The critical channel ID intentionally remains v4. If Android already has
    // this channel, its user-selected settings and the proven Code Red sound
    // remain untouched.
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(
          'tabangnow_notification_v4',
        ),
        enableVibration: true,
        vibrationPattern: _criticalVibrationPattern,
        showBadge: true,
      ),
    );

    await android.createNotificationChannel(
      AndroidNotificationChannel(
        moderateChannelId,
        moderateChannelName,
        description: moderateChannelDescription,
        importance: Importance.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(
          'tabangnow_moderate_v1',
        ),
        enableVibration: true,
        vibrationPattern: _moderateVibrationPattern,
        showBadge: true,
      ),
    );

    await android.createNotificationChannel(
      AndroidNotificationChannel(
        lowChannelId,
        lowChannelName,
        description: lowChannelDescription,
        importance: Importance.defaultImportance,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(
          'tabangnow_low_v1',
        ),
        enableVibration: true,
        vibrationPattern: _lowVibrationPattern,
        showBadge: true,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        silentChannelId,
        silentChannelName,
        description: silentChannelDescription,
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
        showBadge: true,
      ),
    );

    _channelsEnsured = true;
  }

  @pragma('vm:entry-point')
  static Future<void> showFromData(Map<String, dynamic> data) async {
    await initializeBackground();

    final settings = await readSettings();
    if (!settings.notificationsEnabled) {
      await Vibration.cancel();
      await _resetArbiterState();
      return;
    }

    final tier = _tierFromData(data);

    // Give higher tiers a small head start when several FCM messages arrive
    // together. Critical remains immediate. Moderate wins over Low.
    if (tier == TabangNowAlertTier.moderate) {
      await Future<void>.delayed(_moderateCoalesceDelay);
    } else if (tier == TabangNowAlertTier.low) {
      await Future<void>.delayed(_lowCoalesceDelay);
    }

    final decision = await _safeArbitrate(tier);

    switch (tier) {
      case TabangNowAlertTier.critical:
        if (decision.audible) {
          await _showCritical(data, settings);
        } else {
          // Another Code Red is already active. Preserve this event as its own
          // system notification without restarting or stacking the alarm.
          await _showSuppressed(data);
        }
        return;
      case TabangNowAlertTier.moderate:
        if (decision.audible) {
          await _showModerate(data);
        } else {
          await _showSuppressed(data);
        }
        return;
      case TabangNowAlertTier.low:
        if (decision.audible) {
          await _showLow(data);
        } else {
          await _showSuppressed(data);
        }
        return;
      case TabangNowAlertTier.silent:
        await _showSilent(data);
        return;
    }
  }

  static Future<void> _showCritical(
    Map<String, dynamic> data,
    TabangNowNotificationSettings settings,
  ) async {
    final content = _notificationContent(data);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: settings.soundEnabled,
      sound: settings.soundEnabled
          ? const RawResourceAndroidNotificationSound(
              'tabangnow_notification_v4',
            )
          : null,
      enableVibration: settings.vibrationEnabled,
      vibrationPattern: _criticalVibrationPattern,
      autoCancel: false,
      ongoing: true,
      onlyAlertOnce: false,
      additionalFlags: Int32List.fromList(<int>[
        4, // android.app.Notification.FLAG_INSISTENT
      ]),
      channelAction: AndroidNotificationChannelAction.createIfNotExists,
      visibility: NotificationVisibility.private,
      category: AndroidNotificationCategory.alarm,
    );

    await _plugin.show(
      id: persistentAlertId,
      title: content.title,
      body: content.body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: content.payload,
    );

    // Preserve the proven v3/v4 behavior: only the first active CRITICAL
    // alert owns the repeating vibration loop. Additional critical pushes are
    // diverted to silent individual notifications before reaching this method.
    await Vibration.cancel();

    if (settings.vibrationEnabled && settings.hasVibrator) {
      await Vibration.vibrate(
        pattern: <int>[0, 850, 250, 850, 250, 1200],
        repeat: 0,
      );
    }
  }

  static Future<void> _showModerate(Map<String, dynamic> data) async {
    final content = _notificationContent(data);

    await _plugin.show(
      id: _normalNotificationId(data),
      title: content.title,
      body: content.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          moderateChannelId,
          moderateChannelName,
          channelDescription: moderateChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(
            'tabangnow_moderate_v1',
          ),
          enableVibration: true,
          vibrationPattern: _moderateVibrationPattern,
          autoCancel: true,
          ongoing: false,
          onlyAlertOnce: false,
          channelAction: AndroidNotificationChannelAction.createIfNotExists,
          visibility: NotificationVisibility.private,
          category: AndroidNotificationCategory.message,
        ),
      ),
      payload: content.payload,
    );
  }

  static Future<void> _showLow(Map<String, dynamic> data) async {
    final content = _notificationContent(data);

    await _plugin.show(
      id: _normalNotificationId(data),
      title: content.title,
      body: content.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          lowChannelId,
          lowChannelName,
          channelDescription: lowChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(
            'tabangnow_low_v1',
          ),
          enableVibration: true,
          vibrationPattern: _lowVibrationPattern,
          autoCancel: true,
          ongoing: false,
          onlyAlertOnce: false,
          channelAction: AndroidNotificationChannelAction.createIfNotExists,
          visibility: NotificationVisibility.private,
          category: AndroidNotificationCategory.status,
        ),
      ),
      payload: content.payload,
    );
  }

  static Future<void> _showSilent(Map<String, dynamic> data) async {
    final content = _notificationContent(data);

    await _plugin.show(
      id: _normalNotificationId(data),
      title: content.title,
      body: content.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          silentChannelId,
          silentChannelName,
          channelDescription: silentChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: false,
          enableVibration: false,
          autoCancel: true,
          ongoing: false,
          onlyAlertOnce: true,
          channelAction: AndroidNotificationChannelAction.createIfNotExists,
          visibility: NotificationVisibility.private,
          category: AndroidNotificationCategory.status,
        ),
      ),
      payload: content.payload,
    );
  }

  static Future<void> _showSuppressed(Map<String, dynamic> data) async {
    final content = _notificationContent(data);

    await _plugin.show(
      id: _normalNotificationId(data),
      title: content.title,
      body: content.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          silentChannelId,
          silentChannelName,
          channelDescription: silentChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: false,
          enableVibration: false,
          autoCancel: true,
          ongoing: false,
          onlyAlertOnce: true,
          channelAction: AndroidNotificationChannelAction.createIfNotExists,
          visibility: NotificationVisibility.private,
          category: AndroidNotificationCategory.status,
        ),
      ),
      payload: content.payload,
    );
  }

  static Future<_AlertDecision> _safeArbitrate(
    TabangNowAlertTier tier,
  ) async {
    try {
      return await _arbitrate(tier);
    } catch (_) {
      // Notification delivery must survive an unexpected storage/OEM failure.
      // This in-memory fallback still prevents stacking within the active
      // isolate; the OS-locked persistent arbiter remains the normal path.
      return _fallbackArbitrate(tier);
    }
  }

  static _AlertDecision _fallbackArbitrate(TabangNowAlertTier tier) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = _fallbackLastAudibleAtMs > 0
        ? now - _fallbackLastAudibleAtMs
        : null;

    if (tier == TabangNowAlertTier.silent) {
      return const _AlertDecision(audible: false);
    }

    if (tier == TabangNowAlertTier.critical) {
      if (_fallbackCriticalActive) {
        return const _AlertDecision(audible: false);
      }

      _fallbackCriticalActive = true;
      _fallbackLastAudibleTier = 'critical';
      _fallbackLastAudibleAtMs = now;
      return const _AlertDecision(audible: true);
    }

    if (_fallbackCriticalActive) {
      return const _AlertDecision(audible: false);
    }

    if (tier == TabangNowAlertTier.moderate) {
      if (_fallbackLastAudibleTier == 'moderate' &&
          elapsed != null &&
          elapsed < _moderateCooldown.inMilliseconds) {
        return const _AlertDecision(audible: false);
      }

      if (_fallbackLastAudibleTier == 'low' &&
          elapsed != null &&
          elapsed < _minimumAudibleGap.inMilliseconds) {
        return const _AlertDecision(audible: false);
      }

      _fallbackLastAudibleTier = 'moderate';
      _fallbackLastAudibleAtMs = now;
      return const _AlertDecision(audible: true);
    }

    if (tier == TabangNowAlertTier.low) {
      if (_fallbackLastAudibleTier == 'moderate' &&
          elapsed != null &&
          elapsed < _moderateCooldown.inMilliseconds) {
        return const _AlertDecision(audible: false);
      }

      if (_fallbackLastAudibleTier == 'low' &&
          elapsed != null &&
          elapsed < _lowCooldown.inMilliseconds) {
        return const _AlertDecision(audible: false);
      }

      _fallbackLastAudibleTier = 'low';
      _fallbackLastAudibleAtMs = now;
      return const _AlertDecision(audible: true);
    }

    return const _AlertDecision(audible: false);
  }

  static Future<_AlertDecision> _arbitrate(TabangNowAlertTier tier) async {
    if (tier == TabangNowAlertTier.silent) {
      return const _AlertDecision(audible: false);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final systemCriticalActive = await _hasActiveCriticalNotification();

    return _withLockedArbiterState((state) {
      final criticalAge = state.criticalUpdatedAtMs > 0
          ? now - state.criticalUpdatedAtMs
          : null;

      // Reconcile persisted state with Android. The grace window prevents a
      // race where a first critical push has claimed the arbiter but has not
      // yet posted its persistent notification. A null Android state means
      // the OEM/device could not enumerate active notifications, so persisted
      // state is trusted for up to 24 hours instead of being cleared early.
      if (systemCriticalActive == true) {
        state.criticalActive = true;
        if (state.criticalCount < 1) {
          state.criticalCount = 1;
        }
        if (state.criticalUpdatedAtMs <= 0) {
          state.criticalUpdatedAtMs = now;
        }
      } else if (systemCriticalActive == false &&
          state.criticalActive &&
          criticalAge != null &&
          criticalAge > _criticalStateGrace.inMilliseconds) {
        state.criticalActive = false;
        state.criticalCount = 0;
      } else if (systemCriticalActive == null &&
          state.criticalActive &&
          criticalAge != null &&
          criticalAge > _criticalStateMaxAge.inMilliseconds) {
        state.criticalActive = false;
        state.criticalCount = 0;
      }

      if (tier == TabangNowAlertTier.critical) {
        if (state.criticalActive) {
          state.criticalCount += 1;
          state.criticalUpdatedAtMs = now;
          return const _AlertDecision(audible: false);
        }

        state.criticalActive = true;
        state.criticalCount = 1;
        state.criticalUpdatedAtMs = now;
        state.lastAudibleTier = 'critical';
        state.lastAudibleAtMs = now;
        return const _AlertDecision(audible: true);
      }

      if (state.criticalActive) {
        return const _AlertDecision(audible: false);
      }

      final elapsed = state.lastAudibleAtMs > 0
          ? now - state.lastAudibleAtMs
          : null;

      if (tier == TabangNowAlertTier.moderate) {
        if (state.lastAudibleTier == 'moderate' &&
            elapsed != null &&
            elapsed < _moderateCooldown.inMilliseconds) {
          return const _AlertDecision(audible: false);
        }

        // Moderate may preempt a Low cooldown, but never so quickly that the
        // two human-facing sounds stack on top of each other.
        if (state.lastAudibleTier == 'low' &&
            elapsed != null &&
            elapsed < _minimumAudibleGap.inMilliseconds) {
          return const _AlertDecision(audible: false);
        }

        state.lastAudibleTier = 'moderate';
        state.lastAudibleAtMs = now;
        return const _AlertDecision(audible: true);
      }

      if (tier == TabangNowAlertTier.low) {
        if (state.lastAudibleTier == 'moderate' &&
            elapsed != null &&
            elapsed < _moderateCooldown.inMilliseconds) {
          return const _AlertDecision(audible: false);
        }

        if (state.lastAudibleTier == 'low' &&
            elapsed != null &&
            elapsed < _lowCooldown.inMilliseconds) {
          return const _AlertDecision(audible: false);
        }

        state.lastAudibleTier = 'low';
        state.lastAudibleAtMs = now;
        return const _AlertDecision(audible: true);
      }

      return const _AlertDecision(audible: false);
    });
  }

  static Future<bool?> _hasActiveCriticalNotification() async {
    try {
      final active = await _plugin.getActiveNotifications();
      return active.any((notification) => notification.id == persistentAlertId);
    } catch (_) {
      // Persisted state remains the fallback if Android cannot enumerate
      // active notifications on a particular device/OEM build.
      return null;
    }
  }

  static Future<T> _withLockedArbiterState<T>(
    T Function(_AlertArbiterState state) action,
  ) async {
    final directory = Directory(
      '${Directory.systemTemp.path}/tabangnow_notification_arbiter',
    );
    final stateFile = File('${directory.path}/$_arbiterStateFileName');
    final lockFile = File('${directory.path}/$_arbiterLockFileName');

    await directory.create(recursive: true);

    final lock = await lockFile.open(mode: FileMode.append);
    await lock.lock(FileLock.exclusive);

    try {
      final state = await _readArbiterState(stateFile);
      final result = action(state);

      await stateFile.writeAsString(
        jsonEncode(state.toJson()),
        flush: true,
      );

      return result;
    } finally {
      try {
        await lock.unlock();
      } catch (_) {
        // Closing the handle still releases the OS-level lock.
      }
      await lock.close();
    }
  }

  static Future<_AlertArbiterState> _readArbiterState(File stateFile) async {
    try {
      if (!await stateFile.exists()) {
        return _AlertArbiterState();
      }

      final raw = await stateFile.readAsString();
      if (raw.trim().isEmpty) {
        return _AlertArbiterState();
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return _AlertArbiterState();
      }

      return _AlertArbiterState.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return _AlertArbiterState();
    }
  }

  static Future<void> _resetArbiterState() async {
    _fallbackCriticalActive = false;
    _fallbackLastAudibleAtMs = 0;
    _fallbackLastAudibleTier = '';

    try {
      await _withLockedArbiterState((state) {
        state.reset();
      });
    } catch (_) {
      // State cleanup must never prevent the app from opening.
    }
  }

  static Future<void> stopPersistentAlert() async {
    try {
      await _plugin.cancel(id: persistentAlertId);
    } catch (_) {
      // Stopping an alert must never prevent the app from opening.
    }

    try {
      await Vibration.cancel();
    } catch (_) {
      // Stopping vibration must never prevent the app from opening.
    }

    await _resetArbiterState();
  }

  static Future<TabangNowNotificationSettings> readSettings() async {
    if (!_mainInitialized && !_backgroundInitialized) {
      await initializeBackground();
    }

    await _ensureChannels();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    bool notificationsEnabled = true;
    bool channelFound = false;
    bool soundEnabled = true;
    bool vibrationEnabled = true;
    bool hasVibrator = false;

    try {
      notificationsEnabled = await android?.areNotificationsEnabled() ?? true;
    } catch (_) {
      notificationsEnabled = true;
    }

    // These fields intentionally continue representing the CRITICAL/Code Red
    // channel because the existing profile UI already consumes them. Android's
    // app notification settings expose Moderate, Low and Silent independently.
    try {
      final channels = await android?.getNotificationChannels();

      if (channels != null) {
        for (final channel in channels) {
          if (channel.id == channelId) {
            channelFound = true;
            soundEnabled = channel.playSound;
            vibrationEnabled = channel.enableVibration;
            break;
          }
        }
      }
    } catch (_) {
      // If channel inspection is unavailable, preserve the v4 defaults.
    }

    try {
      hasVibrator = await Vibration.hasVibrator();
    } catch (_) {
      hasVibrator = false;
    }

    return TabangNowNotificationSettings(
      notificationsEnabled: notificationsEnabled,
      channelFound: channelFound,
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
      hasVibrator: hasVibrator,
    );
  }

  static Future<bool> requestNotificationPermission() async {
    try {
      if (!_mainInitialized && !_backgroundInitialized) {
        await initializeBackground();
      }

      await _ensureChannels();

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      return await android?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openNotificationSettings() async {
    try {
      if (!_mainInitialized) {
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
        );
        _mainInitialized = true;
      }

      await _ensureChannels();

      return (await _plugin.openAppNotificationSettings()) ?? false;
    } catch (_) {
      return false;
    }
  }

  static TabangNowAlertTier _tierFromData(Map<String, dynamic> data) {
    final explicitTier =
        (data['alert_tier']?.toString() ?? '').trim().toLowerCase();

    switch (explicitTier) {
      case 'critical':
        return TabangNowAlertTier.critical;
      case 'moderate':
        return TabangNowAlertTier.moderate;
      case 'low':
        return TabangNowAlertTier.low;
      case 'silent':
        return TabangNowAlertTier.silent;
    }

    // Backward-compatible safety fallback for an older server payload. Only
    // explicit emergency types may become Code Red. Everything unknown is LOW.
    final type = (data['type']?.toString() ?? '').trim().toLowerCase();
    if (type == 'mobile_emergency' ||
        type == 'emergency' ||
        type == 'calamity') {
      return TabangNowAlertTier.critical;
    }

    return TabangNowAlertTier.low;
  }

  static _NotificationContent _notificationContent(Map<String, dynamic> data) {
    final title = _cleanText(data['title'], fallback: 'TabangNow notification');
    final body = _cleanText(
      data['body'],
      fallback: 'You have a new TabangNow notification.',
    );

    final payload = jsonEncode(<String, dynamic>{
      'notification_id': data['notification_id']?.toString() ?? '',
      'type': data['type']?.toString() ?? '',
      'source_id': data['source_id']?.toString() ?? '',
      'alert_tier': data['alert_tier']?.toString() ?? '',
    });

    return _NotificationContent(title: title, body: body, payload: payload);
  }

  static int _normalNotificationId(Map<String, dynamic> data) {
    final parsed = int.tryParse(data['notification_id']?.toString() ?? '');

    if (parsed != null && parsed > 0 && parsed != persistentAlertId) {
      return parsed;
    }

    var fallback = DateTime.now().millisecondsSinceEpoch.remainder(2000000000);
    if (fallback <= 0 || fallback == persistentAlertId) {
      fallback = persistentAlertId + 1;
    }

    return fallback;
  }

  static Map<String, dynamic>? decodePayload(String? payload) {
    final raw = payload?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  static String _cleanText(Object? value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}

class _AlertDecision {
  const _AlertDecision({required this.audible});

  final bool audible;
}

class _AlertArbiterState {
  _AlertArbiterState({
    this.criticalActive = false,
    this.criticalCount = 0,
    this.criticalUpdatedAtMs = 0,
    this.lastAudibleTier = '',
    this.lastAudibleAtMs = 0,
  });

  bool criticalActive;
  int criticalCount;
  int criticalUpdatedAtMs;
  String lastAudibleTier;
  int lastAudibleAtMs;

  factory _AlertArbiterState.fromJson(Map<String, dynamic> json) {
    return _AlertArbiterState(
      criticalActive: json['critical_active'] == true,
      criticalCount: _safeInt(json['critical_count']),
      criticalUpdatedAtMs: _safeInt(json['critical_updated_at_ms']),
      lastAudibleTier:
          json['last_audible_tier']?.toString().trim().toLowerCase() ?? '',
      lastAudibleAtMs: _safeInt(json['last_audible_at_ms']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'critical_active': criticalActive,
      'critical_count': criticalCount,
      'critical_updated_at_ms': criticalUpdatedAtMs,
      'last_audible_tier': lastAudibleTier,
      'last_audible_at_ms': lastAudibleAtMs,
    };
  }

  void reset() {
    criticalActive = false;
    criticalCount = 0;
    criticalUpdatedAtMs = 0;
    lastAudibleTier = '';
    lastAudibleAtMs = 0;
  }

  static int _safeInt(Object? value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _NotificationContent {
  const _NotificationContent({
    required this.title,
    required this.body,
    required this.payload,
  });

  final String title;
  final String body;
  final String payload;
}
