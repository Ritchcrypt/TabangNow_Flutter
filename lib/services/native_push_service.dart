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

/// Android shows FCM notification payloads automatically in the background.
/// Only data-only messages need Flutter to create a local notification.
/// Foreground rendering continues through FirebaseMessaging.onMessage.
bool shouldRenderLocalBackgroundPush(RemoteMessage message) {
  return message.notification == null;
}

@pragma('vm:entry-point')
Future<void> tabangNowFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (!shouldRenderLocalBackgroundPush(message)) {
    return;
  }

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
  bool _ready = false;
  bool _observerAttached = false;
  bool _listenersAttached = false;
  bool _backgroundHandlerRegistered = false;
  // Fresh-install token provisioning can be temporarily unavailable.
  // Never create overlapping registrations or retry after sign-out.
  Timer? _registrationRetryTimer;
  int _registrationRetryAttempts = 0;
  bool _registrationInProgress = false;
  String _registrationStatus = 'Device registration not started.';

  Future<void> initialize() async {
    if (_ready && _messaging != null) {
      return;
    }

    if (!Platform.isAndroid) {
      return;
    }

    if (!_observerAttached) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    }

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
        FirebaseMessaging.onMessage.listen((message) async {
          NativePushBridge.received(message);

          try {
            await TabangNowNotificationAlert.showFromData(message.data);

            debugPrint(
              '[TabangNow Push] Foreground notification alert rendered.',
            );
          } catch (exception, stackTrace) {
            debugPrint(
              '[TabangNow Push] Foreground notification alert FAILED: '
              '$exception',
            );

            debugPrintStack(stackTrace: stackTrace);
          }
        });

        FirebaseMessaging.onMessageOpenedApp.listen(NativePushBridge.opened);

        messaging.onTokenRefresh.listen((token) {
          final authService = _authenticatedAuthService;

          if (authService != null && token.trim().isNotEmpty) {
            debugPrint('[TabangNow Push] FCM token refreshed.');

            unawaited(syncForAuthenticatedUser(authService));
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

      debugPrint('[TabangNow Push] Firebase initialization FAILED: $exception');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// The last local registration state. It never contains a raw push token.
  String get registrationStatus => _registrationStatus;

  /// A fresh Android installation may need time for Play services to issue
  /// its first FCM token. Try again on a bounded schedule and on app resume.
  static Duration? registrationRetryDelay(int failedAttempts) {
    switch (failedAttempts) {
      case 0:
        return const Duration(seconds: 5);
      case 1:
        return const Duration(seconds: 20);
      case 2:
        return const Duration(minutes: 1);
      case 3:
        return const Duration(minutes: 3);
      default:
        return null;
    }
  }

  void _scheduleRegistrationRetry(AuthService authService) {
    if (!identical(_authenticatedAuthService, authService)) {
      return;
    }

    final delay = registrationRetryDelay(_registrationRetryAttempts);
    if (delay == null) {
      _registrationStatus =
          'Device not registered. Open Notification Settings and tap Retry.';
      return;
    }

    _registrationRetryAttempts++;
    _registrationStatus =
        '$_registrationStatus Retry in ${delay.inSeconds} seconds.';
    _registrationRetryTimer?.cancel();
    _registrationRetryTimer = Timer(delay, () {
      if (identical(_authenticatedAuthService, authService)) {
        unawaited(syncForAuthenticatedUser(authService));
      }
    });
  }

  /// User-triggered retry, independent of any prior automatic retry limit.
  Future<void> retryForAuthenticatedUser(AuthService authService) async {
    _registrationRetryAttempts = 0;
    await syncForAuthenticatedUser(authService);
  }

  Future<void> syncForAuthenticatedUser(AuthService authService) async {
    if (!identical(_authenticatedAuthService, authService)) {
      _registrationRetryAttempts = 0;
    }
    _authenticatedAuthService = authService;

    // Foreground app resume and FCM's token refresh may happen at once.
    if (_registrationInProgress) {
      return;
    }
    _registrationInProgress = true;
    _registrationRetryTimer?.cancel();
    _registrationRetryTimer = null;
    _registrationStatus = 'Connecting device notifications...';

    try {
      if (!_ready || _messaging == null) {
        await initialize();
      }

      final messaging = _messaging;
      if (!_ready || messaging == null) {
        throw StateError('Firebase initialization unavailable.');
      }

      NotificationSettings? settings;
      try {
        settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (exception) {
        // Permission UI can fail while a fresh Activity is initializing.
        // Token registration must still be attempted on Android.
        debugPrint('[TabangNow Push] Permission request failed: $exception');
      }

      final permissionBlocked =
          settings?.authorizationStatus == AuthorizationStatus.denied;
      if (permissionBlocked) {
        debugPrint(
          '[TabangNow Push] Android notifications blocked; '
          'continuing server token registration.',
        );
      }

      final rawToken = await messaging.getToken().timeout(
        const Duration(seconds: 25),
      );
      final token = rawToken?.trim() ?? '';
      if (token.isEmpty) {
        throw StateError('Firebase returned an empty device token.');
      }

      if (!identical(_authenticatedAuthService, authService)) {
        return;
      }
      await _registerToken(token, authService);
      if (!identical(_authenticatedAuthService, authService)) {
        return;
      }

      _registrationRetryAttempts = 0;
      _registrationStatus = permissionBlocked
          ? 'Device registered. Enable notifications in Android settings.'
          : 'Device registered with TabangNow.';
      debugPrint('[TabangNow Push] DEVICE REGISTRATION SUCCESS.');
    } catch (exception, stackTrace) {
      // Do not show FCM tokens, server responses or credentials in the UI.
      debugPrint('[TabangNow Push] DEVICE REGISTRATION FAILED: $exception');
      debugPrintStack(stackTrace: stackTrace);
      _registrationStatus = 'Registration failed (${exception.runtimeType}).';
      _scheduleRegistrationRetry(authService);
    } finally {
      _registrationInProgress = false;
    }
  }

  Future<void> unregisterForAuthenticatedUser(AuthService authService) async {
    _registrationRetryTimer?.cancel();
    _registrationRetryTimer = null;
    _registrationRetryAttempts = 0;
    _registrationStatus = 'Not signed in.';
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
      throw StateError('No authenticated session for push registration.');
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
