import 'package:flutter/material.dart';

import '../core/global_theme_controller.dart';

class ThemeColorPicker extends StatefulWidget {
  const ThemeColorPicker({
    super.key,
    required this.initialColor,
    required this.busy,
    required this.onApply,
  });

  final String initialColor;
  final bool busy;
  final Future<void> Function(String color) onApply;

  @override
  State<ThemeColorPicker> createState() => _ThemeColorPickerState();
}

class _ThemeColorPickerState extends State<ThemeColorPicker> {
  static const List<Color> _quickColors = <Color>[
    Color(0xFF2563EB),
    Color(0xFF0891B2),
    Color(0xFF0F766E),
    Color(0xFF16A34A),
    Color(0xFFCA8A04),
    Color(0xFFEA580C),
    Color(0xFFDC2626),
    Color(0xFFDB2777),
    Color(0xFFC658BD),
    Color(0xFF7C3AED),
    Color(0xFF4F46E5),
    Color(0xFF475569),
  ];

  late Color _selectedColor;
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();

    _selectedColor =
        TabangNowThemeController.parseHexColor(widget.initialColor) ??
        const Color(0xFF2563EB);

    _hexController = TextEditingController(
      text: TabangNowThemeController.toHex(_selectedColor),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(_selectedColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _preview(context),
        const SizedBox(height: 14),
        const Text(
          'Quick colors',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _quickColors.map((color) {
            final selected = color.toARGB32() == _selectedColor.toARGB32();

            return Semantics(
              button: true,
              selected: selected,
              label: 'Use ${TabangNowThemeController.toHex(color)}',
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: widget.busy ? null : () => _setColor(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).dividerColor,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          color: color.computeLuminance() > 0.55
                              ? const Color(0xFF0F172A)
                              : Colors.white,
                        )
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          'Fine tune',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        _slider(
          label: 'Hue',
          value: hsv.hue,
          min: 0,
          max: 360,
          onChanged: (value) => _setColor(hsv.withHue(value).toColor()),
        ),
        _slider(
          label: 'Color',
          value: hsv.saturation,
          min: 0,
          max: 1,
          onChanged: (value) =>
              _setColor(hsv.withSaturation(value).toColor()),
        ),
        _slider(
          label: 'Brightness',
          value: hsv.value,
          min: 0.20,
          max: 1,
          onChanged: (value) => _setColor(hsv.withValue(value).toColor()),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text(
            'Advanced HEX',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Optional — use this only when you need an exact color code.',
            style: TextStyle(fontSize: 11),
          ),
          children: <Widget>[
            TextField(
              controller: _hexController,
              textCapitalization: TextCapitalization.characters,
              onChanged: _onHexChanged,
              decoration: const InputDecoration(
                hintText: '#2563EB',
                helperText: 'Example: #C658BD',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.busy ? null : _apply,
            icon: const Icon(Icons.palette_outlined),
            label: const Text('Apply Custom Color'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.busy
                ? null
                : () => _setColor(const Color(0xFF2563EB)),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Select Default Blue'),
          ),
        ),
      ],
    );
  }

  Widget _preview(BuildContext context) {
    final hex = TabangNowThemeController.toHex(_selectedColor);
    final foreground = _selectedColor.computeLuminance() > 0.55
        ? const Color(0xFF0F172A)
        : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _selectedColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.palette_rounded, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Selected color  $hex',
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            onChanged: widget.busy ? null : onChanged,
          ),
        ),
      ],
    );
  }

  void _setColor(Color color) {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedColor = color;
      _hexController.text = TabangNowThemeController.toHex(color);
    });
  }

  void _onHexChanged(String value) {
    final parsed = TabangNowThemeController.parseHexColor(value);

    if (parsed == null || !mounted) {
      return;
    }

    setState(() {
      _selectedColor = parsed;
    });
  }

  Future<void> _apply() async {
    await widget.onApply(
      TabangNowThemeController.toHex(_selectedColor),
    );
  }
}
