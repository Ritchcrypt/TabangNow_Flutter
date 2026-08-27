import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import 'auth_service.dart';

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
    return NativePushEvent(
      notificationId: notificationIdFromPushData(message.data),
      type: (message.data['type']?.toString() ?? '').trim().toLowerCase(),
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
    final event = NativePushEvent.fromMessage(message, openRequested: true);

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
}

class NativePushService {
  NativePushService._();

  static final NativePushService instance = NativePushService._();

  static const MethodChannel _notificationFeedbackChannel = MethodChannel(
    'tabangnow/notification_feedback',
  );
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

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    if (!Platform.isAndroid) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final messaging = FirebaseMessaging.instance;
      _messaging = messaging;

      FirebaseMessaging.onBackgroundMessage(
        tabangNowFirebaseMessagingBackgroundHandler,
      );

      await messaging.setAutoInitEnabled(true);

      // Request Android notification permission during app startup so
      // Android 13+ users receive the system prompt independently of login.
      // FCM token registration remains tied to authenticated user sync.
      try {
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {
        // Permission prompting must never block Firebase/app startup.
      }

      FirebaseMessaging.onMessage.listen((message) {
        NativePushBridge.received(message);
        unawaited(_playForegroundNotificationFeedback());
      });

      FirebaseMessaging.onMessageOpenedApp.listen(NativePushBridge.opened);

      messaging.onTokenRefresh.listen((token) {
        final authService = _authenticatedAuthService;

        if (authService != null && token.trim().isNotEmpty) {
          unawaited(_registerToken(token.trim(), authService));
        }
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        NativePushBridge.opened(initialMessage);
      }

      _ready = true;
    } catch (_) {
      // Native push must fail open. The existing Laravel notification center
      // and 15-second in-app polling remain the fallback notification path.
      _messaging = null;
      _ready = false;
    }
  }

  Future<void> syncForAuthenticatedUser(AuthService authService) async {
    final messaging = _messaging;

    if (!_ready || messaging == null) {
      return;
    }

    _authenticatedAuthService = authService;

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        await _revokeServerRegistration(authService);
        return;
      }

      final token = (await messaging.getToken())?.trim() ?? '';

      if (token.isEmpty) {
        return;
      }

      await _registerToken(token, authService);
    } catch (_) {
      // Push registration is best-effort. Authentication and the existing
      // notification center must remain usable if Firebase is unavailable.
    }
  }

  Future<void> unregisterForAuthenticatedUser(AuthService authService) async {
    final messaging = _messaging;

    if (!_ready || messaging == null) {
      _authenticatedAuthService = null;
      return;
    }

    try {
      await _revokeServerRegistration(authService);
    } catch (_) {
      // Continue with local token deletion even if the server is unavailable.
    }

    _authenticatedAuthService = null;

    try {
      await messaging.deleteToken();
    } catch (_) {
      // Logout must never be blocked by Firebase cleanup.
    }
  }


  Future<void> _playForegroundNotificationFeedback() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _notificationFeedbackChannel.invokeMethod<void>(
        'playNotificationFeedback',
      );
    } catch (_) {
      // Sound/vibration feedback must never block notification delivery.
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

    if (response.statusCode == 401 || response.statusCode == 403) {
      return;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Push token registration failed with HTTP ${response.statusCode}.',
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
