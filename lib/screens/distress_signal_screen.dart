import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/distress_signal_service.dart';
import 'distress_signal_detail_screen.dart';

class DistressSignalScreen extends StatefulWidget {
  const DistressSignalScreen({
    super.key,
    required this.authService,
    required this.user,
  });

  final AuthService authService;
  final Map<String, dynamic> user;

  @override
  State<DistressSignalScreen> createState() => _DistressSignalScreenState();
}

class _DistressSignalScreenState extends State<DistressSignalScreen> {
  late final DistressSignalService _service;

  bool _loading = true;
  bool _deleting = false;
  String? _error;
  List<Map<String, dynamic>> _alerts = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _service = DistressSignalService(authService: widget.authService);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final alerts = await _service.index();

      if (!mounted) {
        return;
      }

      setState(() {
        _alerts = alerts;
        _loading = false;
      });
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = exception.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Unable to load distress signals.';
      });
    }
  }

  Future<void> _deleteAlert(Map<String, dynamic> alert) async {
    if (_deleting) {
      return;
    }

    final id = _asInt(alert['id']);
    if (id <= 0) {
      return;
    }

    final code = _text(alert['alert_code'], 'this distress signal');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete distress signal?'),
          content: Text(
            'Delete $code from the responder module? This cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _deleting = true;
    });

    try {
      await _service.delete(id);

      if (!mounted) {
        return;
      }

      setState(() {
        _alerts.removeWhere((item) => _asInt(item['id']) == id);
        _deleting = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Distress signal deleted.')),
        );
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _deleting = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(exception.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _deleting = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to delete distress signal.')),
        );
    }
  }

  Future<void> _deleteAll() async {
    if (_deleting || _alerts.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete all distress signals?'),
          content: const Text(
            'This removes all active, acknowledged, and resolved distress '
            'signals from the responder module. This cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
              ),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _deleting = true;
    });

    try {
      final deleted = await _service.deleteAll();

      if (!mounted) {
        return;
      }

      setState(() {
        _alerts = <Map<String, dynamic>>[];
        _deleting = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              deleted == 1
                  ? '1 distress signal deleted.'
                  : '$deleted distress signals deleted.',
            ),
          ),
        );
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _deleting = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(exception.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _deleting = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to delete distress signals.')),
        );
    }
  }

  Future<void> _open(Map<String, dynamic> alert) async {
    final id = _asInt(alert['id']);

    if (id <= 0) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DistressSignalDetailScreen(
          authService: widget.authService,
          alertId: id,
        ),
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'DISTRESS SIGNAL',
                        style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Mobile Emergency Response',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Review emergency details, callback number, device location, and response status.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_alerts.length}',
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_alerts.isNotEmpty) ...<Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _deleting ? null : _deleteAll,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Delete All'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB91C1C),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_alerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: <Widget>[
                  Icon(Icons.notifications_none_rounded, size: 38),
                  SizedBox(height: 10),
                  Text(
                    'No distress signals have been received yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            )
          else
            ..._alerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DistressSignalCard(
                  alert: alert,
                  deleting: _deleting,
                  onTap: () => _open(alert),
                  onDelete: () => _deleteAlert(alert),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DistressSignalCard extends StatelessWidget {
  const _DistressSignalCard({
    required this.alert,
    required this.deleting,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> alert;
  final bool deleting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _text(alert['status'], 'active').toLowerCase();
    final statusColor = switch (status) {
      'resolved' => const Color(0xFF047857),
      'acknowledged' => const Color(0xFFD97706),
      _ => const Color(0xFFDC2626),
    };
    final locationSource = _text(alert['location_source'], 'current');

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _text(alert['alert_code'], 'SOS'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: deleting ? null : onDelete,
                    tooltip: 'Delete distress signal',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _text(
                  alert['emergency_details'],
                  'No emergency description available.',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 7,
                children: <Widget>[
                  _Meta(
                    icon: Icons.phone_rounded,
                    text: _text(alert['contact_number'], 'No mobile number'),
                  ),
                  _Meta(
                    icon: Icons.location_on_outlined,
                    text: locationSource == 'last_known'
                        ? 'Last known location'
                        : 'Current GPS',
                  ),
                  _Meta(
                    icon: Icons.schedule_rounded,
                    text: _text(alert['triggered_at'], 'Unknown time'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _text(alert['display_name'], 'Unidentified mobile user'),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    'View →',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}
