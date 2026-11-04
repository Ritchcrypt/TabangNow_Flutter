import 'package:flutter/material.dart';

import '../core/app_capabilities.dart';
import '../core/app_role.dart';
import '../core/tabangnow_theme.dart';
import '../services/auth_service.dart';
import '../services/resident_complaint_service.dart';
import 'resident_complaint_create_screen.dart';
import 'resident_complaint_detail_screen.dart';

class ResidentComplaintsScreen extends StatefulWidget {
  const ResidentComplaintsScreen({
    super.key,
    required this.authService,
    required this.user,
  });

  final AuthService authService;
  final Map<String, dynamic> user;

  @override
  State<ResidentComplaintsScreen> createState() =>
      _ResidentComplaintsScreenState();
}

class _ResidentComplaintsScreenState extends State<ResidentComplaintsScreen> {
  late final ResidentComplaintService _service;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  List<Map<String, dynamic>> _complaints = <Map<String, dynamic>>[];

  int _currentPage = 1;
  int _lastPage = 1;

  AppRole get _role => AppRoleX.fromRaw(
    widget.user['role']?.toString().trim().toLowerCase() ?? '',
  );

  AppCapabilitySet get _capabilities => AppCapabilities.forRole(_role);

  bool get _canCreate =>
      _capabilities.allows(AppCapability.createResidentComplaint);

  @override
  void initState() {
    super.initState();

    _service = ResidentComplaintService(authService: widget.authService);

    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (append) {
      if (_loadingMore || _currentPage >= _lastPage) {
        return;
      }

      setState(() {
        _loadingMore = true;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final page = append ? _currentPage + 1 : 1;

    try {
      final response = await _service.index(page: page);

      if (!mounted) {
        return;
      }

      final incoming = _mapList(response['data']);

      final pagination = _map(response['pagination']);

      setState(() {
        _complaints = append
            ? <Map<String, dynamic>>[..._complaints, ...incoming]
            : incoming;

        _currentPage = _int(pagination['current_page'], fallback: page);

        _lastPage = _int(pagination['last_page'], fallback: 1);

        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = exception.toString().replaceFirst('AuthException: ', '');
      });
    }
  }

  Future<void> _create() async {
    if (!_canCreate) {
      return;
    }

    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) =>
            ResidentComplaintCreateScreen(service: _service, user: widget.user),
      ),
    );

    if (message == null || !mounted) {
      return;
    }

    _show(message);
    await _load();
  }

  Future<void> _open(int complaintId) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => ResidentComplaintDetailScreen(
          service: _service,
          complaintId: complaintId,
          user: widget.user,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (message != null) {
      _show(message);
    }

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final resident = _role == AppRole.resident;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  resident ? 'My Feedback' : 'Resident Feedback',
                  style: TextStyle(
                    color: palette.textMain,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  resident
                      ? 'Send and track feedback about TabangNow, barangay services, staff response, and community concerns.'
                      : 'Review feedback submitted by residents.',
                  style: TextStyle(color: palette.textMuted),
                ),
                if (_canCreate) ...<Widget>[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Send Feedback'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 100),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else if (_complaints.isEmpty)
            _EmptyCard(resident: resident)
          else
            for (
              var index = 0;
              index < _complaints.length;
              index++
            ) ...<Widget>[
              _ComplaintCard(
                complaint: _complaints[index],
                onOpen: () => _open(_int(_complaints[index]['id'])),
              ),
              if (index != _complaints.length - 1) const SizedBox(height: 12),
            ],

          if (!_loading &&
              _error == null &&
              _currentPage < _lastPage) ...<Widget>[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadingMore ? null : () => _load(append: true),
              icon: _loadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(_loadingMore ? 'Loading...' : 'Load More'),
            ),
          ],
        ],
      ),
    );
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint, required this.onOpen});

  final Map<String, dynamic> complaint;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _text(
                        complaint['complainant_name'],
                        'Unnamed complainant',
                      ),
                      style: TextStyle(
                        color: palette.textMain,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _text(complaint['contact_number'], 'No contact number'),
                      style: TextStyle(color: palette.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                status: _text(complaint['status'], 'submitted'),
                label: _text(complaint['status_label'], 'Submitted'),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            _text(
              complaint['feedback_subject'],
              _text(complaint['complaint_address'], 'No subject provided'),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textMain,
              height: 1.45,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _FeedbackChip(
                label: _text(
                  complaint['feedback_category_label'],
                  'Community Concern',
                ),
              ),
              _FeedbackChip(
                label: _text(
                  complaint['feedback_type_label'],
                  'Concern',
                ),
              ),
              if (complaint['service_rating'] != null)
                _FeedbackChip(
                  label: '${complaint['service_rating']} / 5',
                  icon: Icons.star_rounded,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(Icons.schedule_rounded, size: 15, color: palette.textMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _formatDateTime(complaint['submitted_at']),
                  style: TextStyle(color: palette.textMuted, fontSize: 11),
                ),
              ),
              IconButton(
                tooltip: 'View feedback',
                onPressed: onOpen,
                icon: const Icon(Icons.visibility_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: palette.accentText),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: palette.textSoft,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final colors = _colors(palette, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.$2,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.resident});

  final bool resident;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          const Text('💬', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 12),
          Text(
            'No feedback found',
            style: TextStyle(
              color: palette.textMain,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            resident
                ? 'You have not submitted any feedback yet.'
                : 'No resident feedback has been submitted yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

(Color, Color) _colors(TabangNowTheme palette, String status) {
  return switch (status.toLowerCase()) {
    'submitted' => (
      palette.isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
      palette.isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1D4ED8),
    ),
    'under_review' => (
      palette.isDark ? const Color(0xFF713F12) : const Color(0xFFFEF9C3),
      palette.isDark ? const Color(0xFFFEF08A) : const Color(0xFFA16207),
    ),
    'in_progress' => (
      palette.isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5),
      palette.isDark ? const Color(0xFFFED7AA) : const Color(0xFFC2410C),
    ),
    'resolved' => (
      palette.isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
      palette.isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
    ),
    'rejected' => (
      palette.isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
      palette.isDark ? const Color(0xFFFECACA) : const Color(0xFFB91C1C),
    ),
    _ => (palette.surfaceSoft, palette.textSoft),
  };
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) {
    return <Map<String, dynamic>>[];
  }

  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _text(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? fallback : text;
}

String _formatDateTime(Object? raw) {
  final text = raw?.toString().trim() ?? '';

  if (text.isEmpty) {
    return '—';
  }

  final parsed = DateTime.tryParse(text);

  if (parsed == null) {
    return text;
  }

  final value = parsed.toLocal();
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;

  final minute = value.minute.toString().padLeft(2, '0');

  final suffix = value.hour >= 12 ? 'PM' : 'AM';

  const months = <String>[
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[value.month]} ${value.day}, ${value.year} '
      '$hour:$minute $suffix';
}
