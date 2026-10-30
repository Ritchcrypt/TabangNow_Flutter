import 'package:flutter/material.dart';

import '../core/tabangnow_theme.dart';
import '../services/auth_service.dart';
import '../services/deleted_data_recovery_service.dart';

class DeletedDataRecoveryScreen extends StatefulWidget {
  const DeletedDataRecoveryScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<DeletedDataRecoveryScreen> createState() => _DeletedDataRecoveryScreenState();
}

class _DeletedDataRecoveryScreenState extends State<DeletedDataRecoveryScreen> {
  late final DeletedDataRecoveryService _service;
  final TextEditingController _search = TextEditingController();
  bool _loading = true;
  int? _restoring;
  String? _error;
  String _status = 'recoverable';
  String _type = '';
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  int _recoverable = 0;
  int _restored = 0;
  Map<String, String> _types = <String, String>{};
  List<Map<String, dynamic>> _records = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _service = DeletedDataRecoveryService(authService: widget.authService);
    _load(1);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  int _number(dynamic raw) => int.tryParse(raw?.toString() ?? '') ?? 0;

  String _label(dynamic raw, [String fallback = '']) =>
      raw?.toString().trim().isNotEmpty == true ? raw.toString() : fallback;

  Future<void> _load(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _service.index(
        page: page,
        status: _status,
        type: _type,
        search: _search.text,
      );
      if (!mounted) return;
      final summary = _map(response['summary']);
      final pagination = _map(response['pagination']);
      final rawTypes = _map(response['types']);
      final items = response['data'];
      setState(() {
        _records = items is List ? items.map(_map).toList(growable: false) : [];
        _types = rawTypes.map((key, value) => MapEntry(key, value.toString()));
        _recoverable = _number(summary['recoverable']);
        _restored = _number(summary['restored']);
        final pageNumber = _number(pagination['current_page']);
        _page = pageNumber < 1 ? 1 : pageNumber;
        final lastPageNumber = _number(pagination['last_page']);
        _lastPage = lastPageNumber < 1 ? 1 : lastPageNumber;
        _total = _number(pagination['total']);
        _loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.toString().replaceFirst('AuthException: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _restore(Map<String, dynamic> record) async {
    final id = _number(record['id']);
    if (id <= 0 || _restoring != null || record['can_restore'] != true) return;
    final name = _label(record['resource_label'], 'this deleted record');
    final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Restore deleted data?'),
            content: Text('Restore "$name" and its archived dependent data?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Restore'),
              ),
            ],
          ),
        ) ?? false;
    if (!confirm || !mounted) return;
    setState(() => _restoring = id);
    try {
      final result = await _service.restore(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_label(result['message'], 'Deleted data restored.'))),
      );
      await _load(_page);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('AuthException: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Deleted Data Recovery')),
      body: RefreshIndicator(
        onRefresh: () => _load(_page),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'Restore supported records previously deleted through TabangNow. Administrator access only.',
              style: TextStyle(color: palette.textMuted),
            ),
            const SizedBox(height: 16),
            Row(children: <Widget>[
              Expanded(child: _Counter(label: 'Recoverable', count: _recoverable)),
              const SizedBox(width: 10),
              Expanded(child: _Counter(label: 'Restored', count: _restored)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              maxLength: 200,
              onSubmitted: (_) => _load(1),
              decoration: const InputDecoration(
                labelText: 'Search',
                hintText: 'Record, deleted by, or original ID',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'recoverable', child: Text('Recoverable')),
                DropdownMenuItem(value: 'restored', child: Text('Restored')),
                DropdownMenuItem(value: 'all', child: Text('All')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _status = value);
                _load(1);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Data type'),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem(value: '', child: Text('All types')),
                for (final entry in _types.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _type = value);
                _load(1);
              },
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _loading ? null : () => _load(1),
              icon: const Icon(Icons.search),
              label: const Text('Apply filters'),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(children: <Widget>[
                Text(_error!, style: TextStyle(color: palette.textMain)),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: () => _load(_page), child: const Text('Retry')),
              ])
            else if (_records.isEmpty)
              Padding(
                padding: const EdgeInsets.all(25),
                child: Text(
                  'No recovery records match these filters.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textMuted),
                ),
              )
            else
              for (final record in _records) ...<Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _label(record['resource_type_label'], 'Record'),
                          style: TextStyle(fontWeight: FontWeight.bold, color: palette.textMain),
                        ),
                        const SizedBox(height: 4),
                        Text(_label(record['resource_label'], 'Deleted record')),
                        const SizedBox(height: 6),
                        Text('Original ID: #${_label(record['resource_id'])}'),
                        Text('Deleted by: ${_label(record['deleted_by_name'], 'Unknown user')}'),
                        Text('Deleted: ${_label(record['deleted_at'], 'Unknown')}'),
                        const SizedBox(height: 8),
                        if (record['can_restore'] == true)
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: _restoring != null ? null : () => _restore(record),
                              icon: const Icon(Icons.restore),
                              label: Text(_restoring == _number(record['id']) ? 'Restoring...' : 'Restore'),
                            ),
                          )
                        else
                          const Text('Restored'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            if (!_loading && _error == null) ...<Widget>[
              const SizedBox(height: 8),
              Text('$_total matching records', style: TextStyle(color: palette.textMuted)),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                OutlinedButton(
                  onPressed: _page <= 1 ? null : () => _load(_page - 1),
                  child: const Text('Previous'),
                ),
                Text('Page $_page / $_lastPage'),
                OutlinedButton(
                  onPressed: _page >= _lastPage ? null : () => _load(_page + 1),
                  child: const Text('Next'),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: TextStyle(color: palette.textMuted)),
          Text('$count', style: TextStyle(color: palette.textMain, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
