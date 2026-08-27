import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/auth_service.dart';
import '../services/distress_signal_service.dart';

class DistressSignalDetailScreen extends StatefulWidget {
  const DistressSignalDetailScreen({
    super.key,
    required this.authService,
    required this.alertId,
  });

  final AuthService authService;
  final int alertId;

  @override
  State<DistressSignalDetailScreen> createState() =>
      _DistressSignalDetailScreenState();
}

class _DistressSignalDetailScreenState
    extends State<DistressSignalDetailScreen> {
  late final DistressSignalService _service;

  bool _loading = true;
  bool _changingState = false;
  String? _error;
  Map<String, dynamic> _alert = <String, dynamic>{};

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
      final alert = await _service.show(widget.alertId);

      if (!mounted) {
        return;
      }

      setState(() {
        _alert = alert;
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
        _error = 'Unable to load this distress signal.';
      });
    }
  }

  Future<void> _acknowledge() async {
    await _changeState(() => _service.acknowledge(widget.alertId));
  }

  Future<void> _resolve() async {
    await _changeState(() => _service.resolve(widget.alertId));
  }

  Future<void> _delete() async {
    if (_changingState) {
      return;
    }

    final code = _text(_alert['alert_code'], 'this distress signal');
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
      _changingState = true;
    });

    try {
      await _service.delete(widget.alertId);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _changingState = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(exception.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _changingState = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to delete distress signal.')),
        );
    }
  }

  Future<void> _changeState(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    if (_changingState) {
      return;
    }

    setState(() {
      _changingState = true;
    });

    try {
      final alert = await action();

      if (!mounted) {
        return;
      }

      setState(() {
        _alert = alert;
        _changingState = false;
      });
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _changingState = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(exception.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _changingState = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to update the distress signal.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Distress Signal')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: <Widget>[
                  _AlertHeader(alert: _alert),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Emergency',
                    child: Text(
                      _text(
                        _alert['emergency_details'],
                        'No emergency description available.',
                      ),
                      style: const TextStyle(fontSize: 15, height: 1.55),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Caller',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _Field(
                          label: 'Submitted mobile number',
                          value: _text(
                            _alert['contact_number'],
                            'Not provided',
                          ),
                          emphasize: true,
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          label: 'Linked TabangNow user',
                          value: _text(
                            _alert['display_name'],
                            'Unidentified mobile user',
                          ),
                        ),
                        if (_alert['user'] is Map) ...<Widget>[
                          const SizedBox(height: 14),
                          _Field(
                            label: 'Role',
                            value: _text(
                              Map<String, dynamic>.from(
                                _alert['user'] as Map,
                              )['role'],
                              'Unknown',
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Field(
                            label: 'Registered address',
                            value: _text(
                              Map<String, dynamic>.from(
                                _alert['user'] as Map,
                              )['address'],
                              'Not available',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _locationCard(),
                  const SizedBox(height: 14),
                  _responseCard(),
                ],
              ),
            ),
    );
  }

  Widget _locationCard() {
    final latitude = _doubleOrNull(_alert['latitude']);
    final longitude = _doubleOrNull(_alert['longitude']);

    if (latitude == null || longitude == null) {
      return const _SectionCard(
        title: 'Location',
        child: Text(
          'Location is unavailable for this earlier distress signal.',
        ),
      );
    }

    final point = LatLng(latitude, longitude);
    final source = _text(_alert['location_source'], 'current');

    return _SectionCard(
      title: 'Location',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Field(
            label: 'Location source',
            value: source == 'last_known'
                ? 'Last known device location'
                : 'Current device GPS',
          ),
          const SizedBox(height: 12),
          _Field(label: 'Latitude', value: latitude.toStringAsFixed(7)),
          const SizedBox(height: 10),
          _Field(label: 'Longitude', value: longitude.toStringAsFixed(7)),
          const SizedBox(height: 10),
          _Field(
            label: 'Accuracy',
            value: _alert['accuracy_meters'] == null
                ? 'Not reported'
                : '${_doubleOrNull(_alert['accuracy_meters'])?.toStringAsFixed(1) ?? _alert['accuracy_meters']} meters',
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 230,
              child: FlutterMap(
                options: MapOptions(initialCenter: point, initialZoom: 16),
                children: <Widget>[
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.tabangnow_flutter',
                  ),
                  MarkerLayer(
                    markers: <Marker>[
                      Marker(
                        point: point,
                        width: 52,
                        height: 52,
                        child: const Icon(
                          Icons.location_pin,
                          color: Color(0xFFDC2626),
                          size: 48,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _responseCard() {
    final status = _text(_alert['status'], 'active').toLowerCase();

    return _SectionCard(
      title: 'Response',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              if (status == 'active')
                FilledButton.tonal(
                  onPressed: _changingState ? null : _acknowledge,
                  child: const Text('Acknowledge Distress Signal'),
                ),
              if (status != 'resolved')
                FilledButton(
                  onPressed: _changingState ? null : _resolve,
                  child: const Text('Mark Resolved'),
                ),
              OutlinedButton.icon(
                onPressed: _changingState ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete Distress Signal'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB91C1C),
                ),
              ),
            ],
          ),
          if (_changingState) ...<Widget>[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 18),
          _Field(
            label: 'Acknowledged',
            value: _responseValue('acknowledged_at', 'acknowledged_by'),
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Resolved',
            value: _responseValue('resolved_at', 'resolved_by'),
          ),
        ],
      ),
    );
  }

  String _responseValue(String timeKey, String userKey) {
    final time = _text(_alert[timeKey]);

    if (time.isEmpty) {
      return 'Not yet';
    }

    final rawUser = _alert[userKey];
    final responder = rawUser is Map
        ? _text(Map<String, dynamic>.from(rawUser)['name'])
        : '';

    return responder.isEmpty ? time : '$time by $responder';
  }
}

class _AlertHeader extends StatelessWidget {
  const _AlertHeader({required this.alert});

  final Map<String, dynamic> alert;

  @override
  Widget build(BuildContext context) {
    final status = _text(alert['status'], 'active').toLowerCase();
    final statusColor = switch (status) {
      'resolved' => const Color(0xFF047857),
      'acknowledged' => const Color(0xFFD97706),
      _ => const Color(0xFFDC2626),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'DISTRESS SIGNAL ALERT',
            style: TextStyle(
              color: Color(0xFFB91C1C),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  _text(alert['alert_code'], 'SOS'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Triggered ${_text(alert['triggered_at'], 'Unknown time')}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 17 : 14,
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double? _doubleOrNull(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '');
}
