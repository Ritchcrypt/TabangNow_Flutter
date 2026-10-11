import 'package:flutter/material.dart';

/// Central visual token layer for the authenticated TabangNow interface.
///
/// These values intentionally mirror the website variables in
/// resources/css/app.css so Flutter does not need screen-specific light/dark
/// color decisions.
class TabangNowTheme {
  const TabangNowTheme._({
    required this.isDark,
    required this.pageBackground,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceSoft,
    required this.border,
    required this.borderStrong,
    required this.textMain,
    required this.textSoft,
    required this.textMuted,
    required this.textFaint,
    required this.ring,
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    required this.accentText,
    required this.primaryForeground,
  });

  final bool isDark;

  final Color pageBackground;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceSoft;

  final Color border;
  final Color borderStrong;

  final Color textMain;
  final Color textSoft;
  final Color textMuted;
  final Color textFaint;

  final Color ring;

  final Color accent;
  final Color accentHover;
  final Color accentSoft;
  final Color accentText;
  final Color primaryForeground;

  factory TabangNowTheme.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final isDefaultAccent = accent.toARGB32() == 0xFF2563EB;

    final surface = theme.colorScheme.surface;
    final pageBackground = theme.scaffoldBackgroundColor;

    final accentSoft = isDefaultAccent
        ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE))
        : Color.alphaBlend(
            accent.withValues(alpha: isDark ? 0.30 : 0.14),
            surface,
          );

    final accentText = isDefaultAccent
        ? (isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1D4ED8))
        : accent;

    final primaryForeground = accent.computeLuminance() > 0.55
        ? const Color(0xFF0F172A)
        : Colors.white;

    return TabangNowTheme._(
      isDark: isDark,
      pageBackground: pageBackground,
      surface: surface,
      surfaceMuted: isDark
          ? const Color(0xFF111827)
          : isDefaultAccent
          ? const Color(0xFFF8FAFC)
          : Color.alphaBlend(
              accent.withValues(alpha: 0.055),
              const Color(0xFFF8FAFC),
            ),
      surfaceSoft: isDark
          ? const Color(0xFF1E293B)
          : isDefaultAccent
          ? const Color(0xFFF1F5F9)
          : Color.alphaBlend(
              accent.withValues(alpha: 0.10),
              const Color(0xFFF1F5F9),
            ),
      border: theme.colorScheme.outlineVariant,
      borderStrong: theme.colorScheme.outline,
      textMain: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
      textSoft: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
      textMuted: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
      textFaint: const Color(0xFF94A3B8),
      ring: isDark
          ? const Color(0xFF1D4ED8)
          : isDefaultAccent
          ? const Color(0xFFBFDBFE)
          : Color.alphaBlend(
              accent.withValues(alpha: 0.38),
              surface,
            ),
      accent: accent,
      accentHover: Color.alphaBlend(
        Colors.black.withValues(alpha: 0.14),
        accent,
      ),
      accentSoft: accentSoft,
      accentText: accentText,
      primaryForeground: primaryForeground,
    );
  }
}
