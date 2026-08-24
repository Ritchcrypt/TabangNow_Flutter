import 'package:flutter/material.dart';

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

class TabangNowApp extends StatelessWidget {
  const TabangNowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
