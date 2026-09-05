import 'package:flutter/material.dart';

enum TabangNowThemeMode { light, dark, system, custom }

class TabangNowThemeState {
  const TabangNowThemeState({required this.mode, this.customColor});

  const TabangNowThemeState.system()
    : mode = TabangNowThemeMode.system,
      customColor = null;

  final TabangNowThemeMode mode;
  final Color? customColor;
}

class TabangNowThemeController {
  TabangNowThemeController._();

  static final ValueNotifier<TabangNowThemeState> state =
      ValueNotifier<TabangNowThemeState>(const TabangNowThemeState.system());

  static void apply({required String mode, String? customColor}) {
    final normalized = mode.trim().toLowerCase();

    final parsedMode = switch (normalized) {
      'light' || 'white' => TabangNowThemeMode.light,
      'dark' => TabangNowThemeMode.dark,
      'custom' => TabangNowThemeMode.custom,
      _ => TabangNowThemeMode.system,
    };

    state.value = TabangNowThemeState(
      mode: parsedMode,
      customColor: parsedMode == TabangNowThemeMode.custom
          ? parseHexColor(customColor)
          : null,
    );
  }

  static Color? parseHexColor(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim();

    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(normalized)) {
      return null;
    }

    return Color(int.parse('FF${normalized.substring(1)}', radix: 16));
  }

  static String toHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;

    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static ThemeData themeFor(
    BuildContext context,
    TabangNowThemeState settings,
  ) {
    final platformBrightness = MediaQuery.platformBrightnessOf(context);

    final brightness = switch (settings.mode) {
      TabangNowThemeMode.dark => Brightness.dark,
      TabangNowThemeMode.system => platformBrightness,
      _ => Brightness.light,
    };

    final accent = settings.mode == TabangNowThemeMode.custom
        ? settings.customColor ?? const Color(0xFF2563EB)
        : const Color(0xFF2563EB);

    final isDark = brightness == Brightness.dark;

    final pageBackground = isDark
        ? const Color(0xFF020617)
        : const Color(0xFFF1F5F9);

    final surface = isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);

    final surfaceMuted = isDark
        ? const Color(0xFF111827)
        : const Color(0xFFF8FAFC);

    final surfaceSoft = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF1F5F9);

    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final borderStrong = isDark
        ? const Color(0xFF475569)
        : const Color(0xFFCBD5E1);

    final textMain = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    final textSoft = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

    final textMuted = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF64748B);

    final textFaint = const Color(0xFF94A3B8);

    final primaryForeground = accent.computeLuminance() > 0.55
        ? const Color(0xFF0F172A)
        : Colors.white;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          onPrimary: primaryForeground,
          surface: surface,
          onSurface: textMain,
          outline: borderStrong,
          outlineVariant: border,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: pageBackground,
      canvasColor: surface,
      dividerColor: border,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: textMain,
      displayColor: textMain,
    );

    return base.copyWith(
      textTheme: textTheme,

      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: surface,
        surfaceTintColor: surface,
        foregroundColor: textMain,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textMain),
      ),

      navigationDrawerTheme: base.navigationDrawerTheme.copyWith(
        backgroundColor: const Color(0xFF172554),
      ),

      iconTheme: IconThemeData(color: textSoft),

      dividerTheme: DividerThemeData(color: border),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: TextStyle(color: textMuted),
        floatingLabelStyle: TextStyle(color: accent),
        hintStyle: TextStyle(color: textFaint),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: borderStrong),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: borderStrong),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: primaryForeground,
          disabledBackgroundColor: surfaceSoft,
          disabledForegroundColor: textFaint,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: primaryForeground,
          disabledBackgroundColor: surfaceSoft,
          disabledForegroundColor: textFaint,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: borderStrong),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: surface,
        modalBackgroundColor: surface,
        modalBarrierColor: const Color(0x99020617),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: surface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: textMain,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textSoft),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: surface,
        textStyle: textTheme.bodyMedium?.copyWith(color: textMain),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyMedium?.copyWith(color: textMain),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(surface),
          surfaceTintColor: WidgetStatePropertyAll<Color>(surface),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: isDark
            ? const Color(0xFFBFDBFE)
            : const Color(0xFF93C5FD),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }

          return null;
        }),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }

          return textMuted;
        }),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryForeground;
          }

          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }

          return surfaceSoft;
        }),
      ),

      listTileTheme: ListTileThemeData(
        textColor: textMain,
        iconColor: textMuted,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: surfaceSoft,
        circularTrackColor: surfaceSoft,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
        ),
      ),

      cardColor: surface,
      hoverColor: surfaceMuted,
      focusColor: surfaceSoft,
      highlightColor: surfaceSoft,
      splashColor: accent.withValues(alpha: 0.08),
      disabledColor: textFaint.withValues(alpha: 0.45),
      primaryColor: accent,
      shadowColor: const Color(0x2E020617),
      hintColor: textFaint,
    );
  }
}

class TabangNowGlobalTheme extends StatelessWidget {
  const TabangNowGlobalTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TabangNowThemeState>(
      valueListenable: TabangNowThemeController.state,
      builder: (context, settings, _) {
        return Theme(
          data: TabangNowThemeController.themeFor(context, settings),
          child: child,
        );
      },
    );
  }
}
