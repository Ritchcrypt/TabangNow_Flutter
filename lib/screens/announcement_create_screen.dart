import 'package:flutter/material.dart';

import '../core/tabangnow_theme.dart';
import '../services/announcement_service.dart';

class AnnouncementCreateScreen extends StatefulWidget {
  const AnnouncementCreateScreen({
    super.key,
    required this.service,
    required this.categories,
    required this.priorities,
    required this.audiences,
    required this.barangays,
  });

  final AnnouncementService service;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> priorities;
  final List<Map<String, dynamic>> audiences;
  final List<Map<String, dynamic>> barangays;

  @override
  State<AnnouncementCreateScreen> createState() =>
      _AnnouncementCreateScreenState();
}

class _AnnouncementCreateScreenState extends State<AnnouncementCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _category = 'general';
  String _priority = 'normal';
  String _audience = 'everyone';

  bool _calamityMode = false;
  bool _showInWeatherFeed = false;
  bool _saving = false;
  final Set<int> _selectedBarangayIds = <int>{};
  String? _barangayError;

  @override
  void initState() {
    super.initState();

    _category = _initial(widget.categories, 'general');

    _priority = _initial(widget.priorities, 'normal');

    _audience = _initial(widget.audiences, 'everyone');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _initial(List<Map<String, dynamic>> options, String preferred) {
    final values = options
        .map((item) => item['value']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();

    if (values.contains(preferred)) {
      return preferred;
    }

    return values.isNotEmpty ? values.first : preferred;
  }

  List<(int, String)> get _barangayChoices {
    return widget.barangays
        .map((item) {
          final id = int.tryParse(item['id']?.toString() ?? '');
          final name = item['name']?.toString().trim() ?? '';

          if (id == null || id <= 0 || name.isEmpty) {
            return null;
          }

          return (id, name);
        })
        .whereType<(int, String)>()
        .toList(growable: false);
  }

  void _selectAllBarangays() {
    setState(() {
      _selectedBarangayIds
        ..clear()
        ..addAll(_barangayChoices.map((item) => item.$1));
      _barangayError = null;
    });
  }

  void _clearBarangays() {
    setState(() {
      _selectedBarangayIds.clear();
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedBarangayIds.isEmpty) {
      setState(() {
        _barangayError = 'Select at least one target barangay.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _barangayError = null;
    });

    try {
      final response = await widget.service.create(
        title: _titleController.text,
        content: _contentController.text,
        category: _category,
        priority: _priority,
        audience: _audience,
        barangayIds: _selectedBarangayIds.toList()..sort(),
        calamityMode: _calamityMode,
        showInWeatherFeed: _showInWeatherFeed,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        response['message']?.toString() ?? 'Announcement posted successfully.',
      );
    } catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              exception.toString().replaceFirst('AuthException: ', ''),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(title: const Text('Post Announcement')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: <Widget>[
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Post Announcement',
                    style: TextStyle(
                      color: palette.textMain,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Community announcement, advisory, or emergency notice.',
                    style: TextStyle(color: palette.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Surface(
              child: Column(
                children: <Widget>[
                  TextFormField(
                    controller: _titleController,
                    maxLength: 255,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      hintText: 'Announcement title',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Title is required.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contentController,
                    minLines: 5,
                    maxLines: 10,
                    maxLength: 5000,
                    decoration: const InputDecoration(
                      labelText: 'Content *',
                      hintText: 'Full announcement text...',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Content is required.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _Dropdown(
                    label: 'Category',
                    value: _category,
                    options: widget.categories,
                    enabled: !_saving && !_calamityMode,
                    onChanged: (value) {
                      setState(() {
                        _category = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _Dropdown(
                    label: 'Priority',
                    value: _priority,
                    options: widget.priorities,
                    enabled: !_saving && !_calamityMode,
                    onChanged: (value) {
                      setState(() {
                        _priority = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _Dropdown(
                    label: 'Audience',
                    value: _audience,
                    options: widget.audiences,
                    enabled: !_saving && !_calamityMode,
                    onChanged: (value) {
                      setState(() {
                        _audience = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _TargetBarangaysCard(
                    barangays: _barangayChoices,
                    selectedIds: _selectedBarangayIds,
                    enabled: !_saving,
                    errorText: _barangayError,
                    onSelectAll: _selectAllBarangays,
                    onClear: _clearBarangays,
                    onChanged: (id, selected) {
                      setState(() {
                        if (selected) {
                          _selectedBarangayIds.add(id);
                        } else {
                          _selectedBarangayIds.remove(id);
                        }

                        if (_selectedBarangayIds.isNotEmpty) {
                          _barangayError = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _SettingCard(
                    danger: true,
                    title: '🚨 Activate Calamity Mode',
                    description:
                        'Sends an emergency-priority alert only to matching users in the selected barangays and automatically shows this announcement in the Weather & Disaster Feed.',
                    value: _calamityMode,
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _calamityMode = value;

                              if (value) {
                                _category = 'calamity';
                                _priority = 'emergency';
                                _audience = 'everyone';
                                _showInWeatherFeed = true;
                              }
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  _SettingCard(
                    danger: false,
                    title: 'Show in Weather & Disaster Feed',
                    description:
                        'Use this for PAGASA, MDRRMO, flood, typhoon, evacuation, weather, emergency, or disaster advisories. Normal announcements should stay unchecked.',
                    value: _showInWeatherFeed,
                    onChanged: _saving || _calamityMode
                        ? null
                        : (value) {
                            setState(() {
                              _showInWeatherFeed = value;
                            });
                          },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Post Announcement'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<Map<String, dynamic>> options;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final values = options
        .map((item) => item['value']?.toString() ?? '')
        .where((item) => item.isNotEmpty)
        .toSet();

    final effective = values.contains(value)
        ? value
        : (values.isNotEmpty ? values.first : null);

    return DropdownButtonFormField<String>(
      initialValue: effective,
      decoration: InputDecoration(labelText: label),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option['value']?.toString(),
              child: Text(
                option['label']?.toString() ??
                    option['value']?.toString() ??
                    '',
              ),
            ),
          )
          .toList(growable: false),
      onChanged: enabled
          ? (next) {
              if (next != null) {
                onChanged(next);
              }
            }
          : null,
    );
  }
}

class _TargetBarangaysCard extends StatelessWidget {
  const _TargetBarangaysCard({
    required this.barangays,
    required this.selectedIds,
    required this.enabled,
    required this.errorText,
    required this.onSelectAll,
    required this.onClear,
    required this.onChanged,
  });

  final List<(int, String)> barangays;
  final Set<int> selectedIds;
  final bool enabled;
  final String? errorText;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final void Function(int id, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.accentSoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: errorText == null
              ? palette.accentText.withValues(alpha: 0.22)
              : const Color(0xFFDC2626),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Target Barangays *',
                      style: TextStyle(
                        color: palette.textMain,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Only users assigned to the selected barangays and matching the chosen audience will receive and see this announcement.',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: enabled ? onSelectAll : null,
                child: const Text('Select All'),
              ),
              TextButton(
                onPressed: enabled && selectedIds.isNotEmpty ? onClear : null,
                child: const Text('Clear'),
              ),
              const Spacer(),
              Text(
                '${selectedIds.length}/${barangays.length} selected',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          if (barangays.isEmpty)
            Text(
              'No official Dao barangays are available.',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 12,
              ),
            )
          else
            ...barangays.map(
              (item) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  item.$2,
                  style: TextStyle(
                    color: palette.textSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                value: selectedIds.contains(item.$1),
                onChanged: enabled
                    ? (value) => onChanged(item.$1, value == true)
                    : null,
              ),
            ),
          if (errorText != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              errorText!,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.danger,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final bool danger;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final accent = danger
        ? (palette.isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C))
        : palette.accentText;

    final background = danger
        ? (palette.isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
        : palette.accentSoft;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(color: accent, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
