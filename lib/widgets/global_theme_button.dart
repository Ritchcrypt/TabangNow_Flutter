import 'package:flutter/material.dart';

import '../core/global_theme_controller.dart';
import '../services/auth_service.dart';
import '../services/theme_preference_service.dart';
import 'theme_color_picker.dart';

class GlobalThemeButton extends StatefulWidget {
  const GlobalThemeButton({
    super.key,
    required this.user,
    required this.authService,
  });

  final Map<String, dynamic> user;
  final AuthService authService;

  @override
  State<GlobalThemeButton> createState() => _GlobalThemeButtonState();
}

class _GlobalThemeButtonState extends State<GlobalThemeButton> {
  late final ThemePreferenceService _service;

  bool _loading = true;
  String _mode = 'system';
  String _customColor = '#2563EB';

  @override
  void initState() {
    super.initState();

    _service = ThemePreferenceService(authService: widget.authService);

    _load();
  }

  Future<void> _load() async {
    try {
      final response = await _service.load();
      final raw = response['data'];
      final data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      final mode = (data['theme_mode']?.toString() ?? 'system')
          .trim()
          .toLowerCase();

      final custom = (data['theme_custom_color']?.toString() ?? '#2563EB')
          .trim();

      TabangNowThemeController.apply(mode: mode, customColor: custom);

      if (!mounted) {
        return;
      }

      setState(() {
        _mode = mode;
        _customColor = custom;
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

  Future<void> _apply(String mode, {String? customColor}) async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final response = await _service.update(
        mode: mode,
        customColor: customColor,
      );

      final raw = response['data'];
      final data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      final savedMode = (data['theme_mode']?.toString() ?? mode)
          .trim()
          .toLowerCase();

      final savedColor =
          (data['theme_custom_color']?.toString() ?? customColor ?? '#2563EB')
              .trim();

      TabangNowThemeController.apply(mode: savedMode, customColor: savedColor);

      if (!mounted) {
        return;
      }

      setState(() {
        _mode = savedMode;
        _customColor = savedColor;
        _loading = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Theme preference updated.')),
        );
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(exception.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to update the theme preference.'),
          ),
        );
    }
  }

  String get _icon => switch (_mode) {
    'light' => '☀️',
    'dark' => '🌙',
    'custom' => '🎨',
    _ => '🖥️',
  };

  String get _label => switch (_mode) {
    'light' => 'White',
    'dark' => 'Dark',
    'custom' => 'Custom',
    _ => 'System',
  };

  Future<void> _openThemeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return _ThemePreferenceSheet(
          currentMode: _mode,
          currentColor: _customColor,
          busy: _loading,
          onSelect: (mode) async {
            Navigator.of(sheetContext).pop();
            await _apply(mode);
          },
          onCustom: (color) async {
            Navigator.of(sheetContext).pop();
            await _apply('custom', customColor: color);
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
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _loading ? null : _openThemeSheet,
          child: Tooltip(
            message: 'Current theme: $_label',
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_icon, style: const TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePreferenceSheet extends StatefulWidget {
  const _ThemePreferenceSheet({
    required this.currentMode,
    required this.currentColor,
    required this.busy,
    required this.onSelect,
    required this.onCustom,
  });

  final String currentMode;
  final String currentColor;
  final bool busy;
  final Future<void> Function(String mode) onSelect;
  final Future<void> Function(String color) onCustom;

  @override
  State<_ThemePreferenceSheet> createState() => _ThemePreferenceSheetState();
}

class _ThemePreferenceSheetState extends State<_ThemePreferenceSheet> {
  late final TextEditingController _colorController;

  @override
  void initState() {
    super.initState();

    _colorController = TextEditingController(
      text: widget.currentColor.toUpperCase(),
    );
  }

  @override
  void dispose() {
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 20 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Theme Preference',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Current: ${_label(widget.currentMode)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            _option(
              context,
              mode: 'light',
              icon: '☀️',
              title: 'White',
              description: 'Use the bright default interface.',
            ),
            _option(
              context,
              mode: 'dark',
              icon: '🌙',
              title: 'Dark',
              description: 'Use a darker interface.',
            ),
            _option(
              context,
              mode: 'system',
              icon: '🖥️',
              title: 'System',
              description: 'Follow your device appearance.',
            ),
            const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),
              const Text(
                'CUSTOM COLOR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              ThemeColorPicker(
                initialColor: widget.currentColor,
                busy: widget.busy,
                onApply: (color) {
                  _colorController.text = color;
                  return _applyCustom();
                },
              ),
              const SizedBox(height: 6),
              Text(
                'Applies only to your account on web and mobile.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required String mode,
    required String icon,
    required String title,
    required String description,
  }) {
    final selected = widget.currentMode == mode;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.busy ? null : () => widget.onSelect(mode),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selected ? scheme.onPrimaryContainer : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_rounded, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyCustom() async {
    final value = _colorController.text.trim();

    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Enter a valid HEX color such as #2563EB.'),
          ),
        );

      return;
    }

    await widget.onCustom(value.toUpperCase());
  }

  String _label(String mode) => switch (mode) {
    'light' => 'White',
    'dark' => 'Dark',
    'custom' => 'Custom',
    _ => 'System',
  };
}
