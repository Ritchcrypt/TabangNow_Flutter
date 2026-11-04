import 'package:flutter/material.dart';

import '../services/dao_news_service.dart';

/// Admin only; Laravel authorizes every request independently.
class DaoNewsManager extends StatefulWidget {
  const DaoNewsManager({super.key, required this.service, required this.onChanged});
  final DaoNewsService service;
  final VoidCallback onChanged;

  @override
  State<DaoNewsManager> createState() => _DaoNewsManagerState();
}

class _DaoNewsManagerState extends State<DaoNewsManager> {
  bool _expanded = false;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _entries = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _audit = <Map<String, dynamic>>[];
  List<String> _topics = <String>[];

  Map<String, dynamic> _asMap(dynamic raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  Future<void> _load() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.service.manage();
      if (!mounted) return;
      setState(() {
        _entries = (data['entries'] is List)
            ? (data['entries'] as List).map(_asMap).toList() : [];
        _audit = (data['audit'] is List)
            ? (data['audit'] as List).map(_asMap).toList() : [];
        _topics = (data['topics'] is List)
            ? (data['topics'] as List).map((e) => e.toString()).toList() : [];
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Unable to read signed news records. Check Laravel before making changes.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(String action, {String? id, String? url,
    String? topic, String? published, bool confirmed = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.service.act(action, id: id, url: url,
        topic: topic, published: published, confirmed: confirmed);
      if (!mounted) return;
      setState(() => _loading = false);
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('News link $action completed.')),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $error')),
        );
      }
    }
  }

  Future<bool> _confirm(String title, String explanation) async {
    return await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: Text(explanation),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
      ],
    )) ?? false;
  }

  Future<void> _edit({Map<String, dynamic>? item, bool reviewOnly = false}) async {
    if (_loading || !mounted) return;

    // Route owns text controllers. Do not dispose them when showDialog's
    // Future completes: the closing route may still be animating out.
    final result = await showDialog<_DaoNewsEditResult>(
      context: context,
      builder: (dialogContext) => _DaoNewsEditDialog(
        item: item,
        reviewOnly: reviewOnly,
        topics: List<String>.of(_topics),
      ),
    );
    if (!mounted || result == null) return;

    await _action(
      reviewOnly ? 'review' : item != null ? 'edit' : 'add',
      id: item?['id']?.toString(),
      url: reviewOnly ? null : result.url,
      topic: reviewOnly ? null : result.topic,
      published: result.published,
      confirmed: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        title: const Text('Manage external news links (Admin only)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        onExpansionChanged: (value) {
          setState(() => _expanded = value);
          if (value) _load();
        },
        children: !_expanded ? [] : [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Padding(padding: const EdgeInsets.all(12),
            child: Text(_error!, style: const TextStyle(color: Colors.red))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(spacing: 8, children: [
              TextButton.icon(onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh), label: const Text('Refresh')),
              FilledButton.icon(onPressed: _loading || _error != null ? null : () => _edit(),
                icon: const Icon(Icons.add), label: const Text('Add link')),
            ])),
          ..._entries.map((entry) {
            final id = entry['id']?.toString() ?? '';
            final approved = entry['approved'] == true;
            final trusted = entry['trusted'] == true;
            return Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 6), child: Card(
              child: Padding(padding: const EdgeInsets.all(10), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(entry['topic']?.toString() ?? 'Dao update',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(entry['url']?.toString() ?? '',
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                  Text('${entry['published'] ?? ''} · ${approved ? 'Approved' : 'Hidden / review required'}',
                    style: Theme.of(context).textTheme.bodySmall),
                  Wrap(spacing: 4, runSpacing: 2, children: [
                    TextButton(onPressed: _loading ? null : () => _edit(item: entry),
                      child: const Text('Edit')),
                    if (!approved && trusted)
                      TextButton(onPressed: _loading ? null : () => _edit(item: entry, reviewOnly: true),
                        child: const Text('Review')),
                    TextButton(onPressed: _loading ? null : () => _action('check', id: id),
                      child: const Text('Check link')),
                    TextButton(onPressed: _loading ? null : () async {
                      if (await _confirm('Unpublish article?', 'Hide this article until it is reviewed again.')) {
                        await _action('unpublish', id: id);
                      }
                    }, child: const Text('Unpublish')),
                    TextButton(onPressed: _loading ? null : () async {
                      if (await _confirm('Remove article?', 'Remove this link from TabangNow? The audit event remains.')) {
                        await _action('remove', id: id);
                      }
                    }, child: const Text('Remove')),
                  ]),
                ],
              )),
            ));
          }),
          ExpansionTile(
            title: const Text('News audit history (latest 40)'),
            subtitle: const Text('Recent changes to news links'),
            children: _audit.isEmpty
                ? <Widget>[
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No recent news changes.'),
                    ),
                  ]
                : _audit.map((event) => ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 3,
                    ),
                    title: Text(
                      DaoNewsAuditPresentation.title(event),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${DaoNewsAuditPresentation.date(event)}\n'
                      '${DaoNewsAuditPresentation.article(event)}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
          ),
        ],
      ),
    );
  }
}

/// Only values (never controllers or widget contexts) escape the dialog route.
class _DaoNewsEditResult {
  const _DaoNewsEditResult({
    required this.url,
    required this.topic,
    required this.published,
  });

  final String url;
  final String topic;
  final String published;
}

/// Stateful route contents dispose their own controllers at the same point
/// Flutter removes the text fields, avoiding pop-animation lifecycle races.
class _DaoNewsEditDialog extends StatefulWidget {
  const _DaoNewsEditDialog({
    required this.item,
    required this.reviewOnly,
    required this.topics,
  });

  final Map<String, dynamic>? item;
  final bool reviewOnly;
  final List<String> topics;

  @override
  State<_DaoNewsEditDialog> createState() => _DaoNewsEditDialogState();
}

class _DaoNewsEditDialogState extends State<_DaoNewsEditDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _dateController;
  late String _topic;
  bool _sourceChecked = false;
  bool _relevanceChecked = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.item?['url']?.toString() ?? '',
    );
    _dateController = TextEditingController(
      text: widget.item?['published']?.toString() ?? '',
    );
    final existingTopic = widget.item?['topic']?.toString() ?? '';
    _topic = widget.topics.contains(existingTopic)
        ? existingTopic
        : widget.topics.isNotEmpty
            ? widget.topics.first
            : '';
    _urlController.addListener(_refreshValidation);
    _dateController.addListener(_refreshValidation);
  }

  void _refreshValidation() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _urlController.removeListener(_refreshValidation);
    _dateController.removeListener(_refreshValidation);
    _urlController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  bool get _valid =>
      _sourceChecked &&
      _relevanceChecked &&
      _dateController.text.trim().isNotEmpty &&
      (widget.reviewOnly ||
          (_urlController.text.trim().isNotEmpty &&
              widget.topics.contains(_topic)));

  Future<void> _selectDate() async {
    final today = DateTime.now().toUtc();
    final lastDate = DateTime.utc(today.year, today.month, today.day);
    final firstDate = lastDate.subtract(const Duration(days: 90));
    final savedDate = DateTime.tryParse(_dateController.text);
    final initialDate = savedDate == null ||
            savedDate.isBefore(firstDate) ||
            savedDate.isAfter(lastDate)
        ? lastDate
        : savedDate;

    final selected = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
    );
    if (!mounted || selected == null) return;
    _dateController.text =
        '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
  }

  void _save() {
    if (!_valid) return;
    Navigator.of(context).pop(
      _DaoNewsEditResult(
        url: _urlController.text.trim(),
        topic: _topic,
        published: _dateController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Account for dialog insets and content padding even on 270px phones.
    final contentWidth = (screenWidth - 66).clamp(180.0, 480.0).toDouble();
    final title = widget.reviewOnly
        ? 'Review link'
        : widget.item != null
            ? 'Edit news link'
            : 'Add Dao news link';

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      titlePadding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      title: Text(title, style: const TextStyle(fontSize: 19)),
      content: SizedBox(
        width: contentWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Use the original publisher link. Article text and images stay on the publisher site.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            if (!widget.reviewOnly) ...<Widget>[
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                minLines: 1,
                maxLines: 2,
                maxLength: 1800,
                decoration: const InputDecoration(
                  labelText: 'Publisher HTTPS URL',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: widget.topics.contains(_topic) ? _topic : null,
                items: widget.topics
                    .map((value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _topic = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                isExpanded: true,
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _dateController,
              readOnly: true,
              onTap: _selectDate,
              decoration: InputDecoration(
                labelText: 'Publication date (UTC)',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  tooltip: 'Choose publication date',
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: _selectDate,
                ),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _sourceChecked,
              dense: true,
              isThreeLine: false,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              title: const Text(
                'I verified the original publisher, article and URL.',
                style: TextStyle(fontSize: 12),
              ),
              onChanged: (value) {
                setState(() => _sourceChecked = value ?? false);
              },
            ),
            CheckboxListTile(
              value: _relevanceChecked,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              title: const Text(
                'I confirmed this update concerns Dao, Capiz.',
                style: TextStyle(fontSize: 12),
              ),
              onChanged: (value) {
                setState(() => _relevanceChecked = value ?? false);
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        SizedBox(
          width: contentWidth,
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _valid ? _save : null,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


/// Human-readable labels only. The Laravel audit history, actor IDs,
/// event hashes and before/after values remain unchanged on the server.
class DaoNewsAuditPresentation {
  const DaoNewsAuditPresentation._();

  static Map<String, dynamic> _articleRecord(Map<String, dynamic> event) {
    final after = event['after'];
    final before = event['before'];
    final record = after is Map ? after : before is Map ? before : null;
    return record == null ? <String, dynamic>{} : Map<String, dynamic>.from(record);
  }

  static String title(Map<String, dynamic> event) {
    final action = event['action']?.toString() ?? '';
    switch (action) {
      case 'added':
        return 'Article added';
      case 'edited':
        return 'Article updated';
      case 'reviewed':
        return 'Article approved';
      case 'unpublished':
        return 'Article hidden';
      case 'removed':
        return 'Article removed';
      case 'link_checked':
        final status = _articleRecord(event)['link_status']?.toString() ?? '';
        switch (status) {
          case 'ok':
            return 'Link checked: available';
          case 'broken':
            return 'Link checked: unavailable';
          case 'redirected':
            return 'Link checked: redirected';
          case 'manual_check':
            return 'Link checked: needs review';
          default:
            return 'Link checked';
        }
      default:
        return 'News link updated';
    }
  }

  static String date(Map<String, dynamic> event) {
    final raw = event['at']?.toString() ?? '';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return 'Date unavailable';
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final amPm = parsed.hour < 12 ? 'AM' : 'PM';
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}'
        ' · $hour:$minute $amPm';
  }

  static String article(Map<String, dynamic> event) {
    final record = _articleRecord(event);
    final url = record['url']?.toString() ?? '';
    final topic = record['topic']?.toString() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return topic.isNotEmpty ? topic : 'Article details unavailable';
    }
    final host = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    final slug = segments.isEmpty ? '' : segments.last;
    final readable = slug.replaceAll(RegExp(r'[-_]+'), ' ').trim();
    final detail = readable.isNotEmpty ? readable : topic;
    if (detail.isEmpty) return host;
    final shortDetail = detail.length > 55
        ? '${detail.substring(0, 52)}...'
        : detail;
    return '$host · $shortDetail';
  }
}
