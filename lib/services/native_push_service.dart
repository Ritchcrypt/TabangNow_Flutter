import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import 'auth_service.dart';
import 'background_notification_alert_service.dart';

int? notificationIdFromPushData(Map<String, dynamic> data) {
  final raw = data['notification_id'];

  if (raw is int) {
    return raw > 0 ? raw : null;
  }

  final parsed = int.tryParse(raw?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

class NativePushEvent {
  const NativePushEvent({
    required this.notificationId,
    required this.type,
    required this.openRequested,
  });

  final int? notificationId;
  final String type;
  final bool openRequested;

  bool get isEmergency => type == 'mobile_emergency' || type == 'emergency';

  factory NativePushEvent.fromMessage(
    RemoteMessage message, {
    required bool openRequested,
  }) {
    return NativePushEvent.fromData(message.data, openRequested: openRequested);
  }

  factory NativePushEvent.fromData(
    Map<String, dynamic> data, {
    required bool openRequested,
  }) {
    return NativePushEvent(
      notificationId: notificationIdFromPushData(data),
      type: (data['type']?.toString() ?? '').trim().toLowerCase(),
      openRequested: openRequested,
    );
  }
}

class NativePushBridge {
  NativePushBridge._();

  static final StreamController<NativePushEvent> _events =
      StreamController<NativePushEvent>.broadcast();

  static int? _pendingOpenNotificationId;

  static Stream<NativePushEvent> get events => _events.stream;

  static void received(RemoteMessage message) {
    _events.add(NativePushEvent.fromMessage(message, openRequested: false));
  }

  static void opened(RemoteMessage message) {
    openedData(message.data);
  }

  static void openedData(Map<String, dynamic> data) {
    final event = NativePushEvent.fromData(data, openRequested: true);

    if (event.notificationId != null) {
      _pendingOpenNotificationId = event.notificationId;
    }

    _events.add(event);
  }

  static int? takePendingOpenNotificationId() {
    final pending = _pendingOpenNotificationId;
    _pendingOpenNotificationId = null;
    return pending;
  }

  static void clearPendingOpenNotificationId(int? notificationId) {
    if (notificationId != null &&
        _pendingOpenNotificationId == notificationId) {
      _pendingOpenNotificationId = null;
    }
  }
}

@pragma('vm:entry-point')
Future<void> tabangNowFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await TabangNowNotificationAlert.showFromData(message.data);
}

class NativePushService with WidgetsBindingObserver {
  NativePushService._();

  static final NativePushService instance = NativePushService._();

  static const String _installationIdKey =
      'tabangnow_emergency_installation_id';
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  FirebaseMessaging? _messaging;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final http.Client _client = http.Client();

  AuthService? _authenticatedAuthService;
  bool _initialized = false;
  bool _ready = false;
  bool _observerAttached = false;
  bool _listenersAttached = false;
  bool _backgroundHandlerRegistered = false;

  Future<void> initialize() async {
    if (_ready && _messaging != null) {
      return;
    }

    if (!Platform.isAndroid) {
      _initialized = true;
      return;
    }

    if (!_observerAttached) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    }

    _initialized = true;

    try {
      final launchData = await TabangNowNotificationAlert.initializeMain(
        onOpened: NativePushBridge.openedData,
      );
      await TabangNowNotificationAlert.stopPersistentAlert();

      if (launchData != null) {
        NativePushBridge.openedData(launchData);
      }
    } catch (_) {
      // Preserve the existing Firebase/token path even if local-alert setup fails.
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final messaging = FirebaseMessaging.instance;
      _messaging = messaging;

      if (!_backgroundHandlerRegistered) {
        FirebaseMessaging.onBackgroundMessage(
          tabangNowFirebaseMessagingBackgroundHandler,
        );
        _backgroundHandlerRegistered = true;
      }

      await messaging.setAutoInitEnabled(true);

      try {
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {}

      if (!_listenersAttached) {
        FirebaseMessaging.onMessage.listen((message) {
          NativePushBridge.received(message);
        });

        FirebaseMessaging.onMessageOpenedApp.listen(NativePushBridge.opened);

        messaging.onTokenRefresh.listen((token) {
          final authService = _authenticatedAuthService;

          if (authService != null && token.trim().isNotEmpty) {
            debugPrint('[TabangNow Push] FCM token refreshed.');

            unawaited(_registerToken(token.trim(), authService));
          }
        });

        _listenersAttached = true;
      }

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        NativePushBridge.opened(initialMessage);
      }

      _ready = true;
    } catch (exception, stackTrace) {
      _messaging = null;
      _ready = false;
      _initialized = false;

      debugPrint('[TabangNow Push] Firebase initialization FAILED: $exception');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> syncForAuthenticatedUser(AuthService authService) async {
    _authenticatedAuthService = authService;

    /*
     * The application may have experienced a temporary Firebase startup
     * failure before authentication completed. Retry here instead of leaving
     * the device permanently unregistered.
     */
    if (!_ready || _messaging == null) {
      debugPrint(
        '[TabangNow Push] Firebase not ready; retrying initialization.',
      );

      await initialize();
    }

    final messaging = _messaging;

    if (!_ready || messaging == null) {
      debugPrint(
        '[TabangNow Push] Registration aborted: Firebase unavailable.',
      );
      return;
    }

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint(
        '[TabangNow Push] Permission: '
        '${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[TabangNow Push] Notification permission denied.');
        return;
      }

      final token = (await messaging.getToken())?.trim() ?? '';

      if (token.isEmpty) {
        throw StateError('Firebase returned an empty FCM token.');
      }

      debugPrint(
        '[TabangNow Push] FCM token acquired '
        '(length=${token.length}).',
      );

      await _registerToken(token, authService);

      debugPrint('[TabangNow Push] DEVICE REGISTRATION SUCCESS.');
    } catch (exception, stackTrace) {
      debugPrint('[TabangNow Push] DEVICE REGISTRATION FAILED: $exception');

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> unregisterForAuthenticatedUser(AuthService authService) async {
    await TabangNowNotificationAlert.stopPersistentAlert();

    final messaging = _messaging;

    if (!_ready || messaging == null) {
      _authenticatedAuthService = null;
      return;
    }

    try {
      await _revokeServerRegistration(authService);
    } catch (_) {}

    _authenticatedAuthService = null;

    try {
      await messaging.deleteToken();
    } catch (_) {}
  }

  Future<TabangNowNotificationSettings> notificationSettings() async {
    return TabangNowNotificationAlert.readSettings();
  }

  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }

    return TabangNowNotificationAlert.requestNotificationPermission();
  }

  Future<bool> openNotificationSettings() async {
    if (!Platform.isAndroid) {
      return false;
    }

    return TabangNowNotificationAlert.openNotificationSettings();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    unawaited(TabangNowNotificationAlert.stopPersistentAlert());

    final authService = _authenticatedAuthService;

    if (authService != null) {
      unawaited(syncForAuthenticatedUser(authService));
    }
  }

  Future<void> _registerToken(String fcmToken, AuthService authService) async {
    final authToken = (await authService.getToken())?.trim() ?? '';

    if (authToken.isEmpty) {
      return;
    }

    final installationId = await _installationId();

    final response = await _client
        .post(
          Uri.parse('$_baseUrl/api/v1/push-tokens'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode(<String, dynamic>{
            'installation_id': installationId,
            'fcm_token': fcmToken,
            'device_name': 'TabangNow Android',
            'platform': 'android',
          }),
        )
        .timeout(_requestTimeout);

    debugPrint(
      '[TabangNow Push] Laravel push-token HTTP '
      '${response.statusCode}.',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final responseText = response.body.length > 500
          ? response.body.substring(0, 500)
          : response.body;

      throw StateError(
        'Push token registration failed with HTTP '
        '${response.statusCode}: $responseText',
      );
    }
  }

  Future<void> _revokeServerRegistration(AuthService authService) async {
    final authToken = (await authService.getToken())?.trim() ?? '';
    final installationId = await _existingInstallationId();

    if (authToken.isEmpty || installationId == null) {
      return;
    }

    final response = await _client
        .delete(
          Uri.parse('$_baseUrl/api/v1/push-tokens/current'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode(<String, dynamic>{
            'installation_id': installationId,
          }),
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 401 &&
        response.statusCode != 403 &&
        (response.statusCode < 200 || response.statusCode >= 300)) {
      throw StateError(
        'Push token revocation failed with HTTP ${response.statusCode}.',
      );
    }
  }

  Future<String?> _existingInstallationId() async {
    final existing =
        (await _secureStorage.read(key: _installationIdKey))?.trim() ?? '';
    return existing.isEmpty ? null : existing;
  }

  Future<String> _installationId() async {
    final existing = await _existingInstallationId();

    if (existing != null) {
      return existing;
    }

    final random = Random.secure();
    final suffix = List<int>.generate(
      12,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

    final generated =
        'android-${DateTime.now().microsecondsSinceEpoch}-$suffix';

    await _secureStorage.write(key: _installationIdKey, value: generated);

    return generated;
  }
}
