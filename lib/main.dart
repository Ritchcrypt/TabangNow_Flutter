import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/reset_password_screen.dart';
import 'services/auth_service.dart';
import 'services/reset_password_link_policy.dart';

import 'core/global_theme_controller.dart';
import 'services/native_push_service.dart';

import 'widgets/global_sos_overlay.dart';

import 'screens/auth_gate.dart';
import 'widgets/mobile_update_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NativePushService.instance.initialize();

  runApp(const TabangNowApp());
}

class TabangNowApp extends StatefulWidget {
  const TabangNowApp({super.key});

  @override
  State<TabangNowApp> createState() => _TabangNowAppState();
}

class _TabangNowAppState extends State<TabangNowApp> {
  static const MethodChannel _resetLinks = MethodChannel('tabangnow/password_reset_links');
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _resetPageOpen = false;
  String? _pendingLink;

  @override
  void initState() {
    super.initState();
    _resetLinks.setMethodCallHandler((call) async {
      if (call.method == 'onResetLink' && call.arguments is String) {
        _receiveResetLink(call.arguments as String);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final link = await _resetLinks.invokeMethod<String>('getInitialResetLink');
        if (link != null) _receiveResetLink(link);
      } on MissingPluginException {
        // Flutter may also run on desktop/web where Android MethodChannel is absent.
      } on PlatformException {
        // Preserve normal login if the device cannot supply its launch intent.
      }
    });
  }

  void _receiveResetLink(String raw) {
    final resetLink = PasswordResetLinkPolicy.parse(raw);
    if (resetLink == null || _resetPageOpen) return;

    final token = resetLink.token;
    final email = resetLink.email;

    final nav = _navigatorKey.currentState;
    if (nav == null) {
      _pendingLink = raw;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pending = _pendingLink;
        _pendingLink = null;
        if (pending != null && mounted) _receiveResetLink(pending);
      });
      return;
    }
    _resetPageOpen = true;
    nav.push<void>(MaterialPageRoute<void>(
      builder: (_) => ResetPasswordScreen(
        token: token,
        email: email,
        authService: AuthService(),
      ),
    )).whenComplete(() => _resetPageOpen = false);
  }

  @override
  void dispose() {
    _resetLinks.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      builder: (context, child) => TabangNowGlobalTheme(
        child: GlobalSosOverlay(child: child ?? const SizedBox.shrink()),
      ),
      title: 'TabangNow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A8A)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const MobileUpdateGate(child: AuthGate()),
    );
  }
}
