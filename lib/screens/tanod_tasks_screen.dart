import 'package:flutter/material.dart';

import '../core/app_capabilities.dart';
import '../core/app_role.dart';
import '../core/tabangnow_theme.dart';
import '../services/auth_service.dart';
import '../services/tanod_task_service.dart';

class TanodTasksScreen extends StatefulWidget {
  const TanodTasksScreen({
    super.key,
    required this.authService,
    required this.user,
  });

  final AuthService authService;
  final Map<String, dynamic> user;

  @override
  State<TanodTasksScreen> createState() => _TanodTasksScreenState();
}

class _TanodTasksScreenState extends State<TanodTasksScreen> {
  late final TanodTaskService _service;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  Map<String, dynamic> _summary = <String, dynamic>{};
  Map<String, dynamic> _permissions = <String, dynamic>{};
  List<Map<String, dynamic>> _barangayOptions = <Map<String, dynamic>>[];

  int _currentPage = 1;
  int _lastPage = 1;

  AppRole get _role => AppRoleX.fromRaw(widget.user['role']?.toString());

  AppCapabilitySet get _capabilities => AppCapabilities.forRole(_role);

  bool get _admin => _capabilities.allows(AppCapability.manageTanodTasks);

  bool get _tanod => _capabilities.allows(AppCapability.respondToTanodTasks);

  @override
  void initState() {
    super.initState();
    _service = TanodTaskService(authService: widget.authService);

    if (_admin || _tanod) {
      _load();
    } else {
      _loading = false;
      _error = 'Tanod Tasks is not available for this account role.';
    }
  }

  Future<void> _load({bool append = false}) async {
    if (!(_admin || _tanod)) {
      return;
    }

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
      final response = await _service.tasks(page: page);

      if (!mounted) {
        return;
      }

      final incoming = _mapList(response['data']);
      final pagination = _map(response['pagination']);
      final options = _map(response['options']);
      final barangays = _mapList(options['barangays']);

      setState(() {
        _items = append
            ? <Map<String, dynamic>>[..._items, ...incoming]
            : incoming;
        _summary = _map(response['summary']);
        _permissions = _map(response['permissions']);
        if (barangays.isNotEmpty) {
          _barangayOptions = barangays;
        }
        _currentPage = _toInt(pagination['current_page']) ?? page;
        _lastPage = _toInt(pagination['last_page']) ?? 1;
        _loading = false;
        _loadingMore = false;
      });
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = exception.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Unable to load Tanod Tasks.';
      });
    }
  }

  Future<void> _createTask() async {
    if (!_admin) {
      return;
    }

    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreateTaskSheet(
        service: _service,
        activeTanodCount: _toInt(_summary['active_tanod_count']) ?? 0,
        barangayOptions: _barangayOptions,
      ),
    );

    if (!mounted || message == null) {
      return;
    }

    _show(message);
    await _load();
  }

  Future<void> _showTaskDetails(Map<String, dynamic> task) async {
    if (!_admin) {
      return;
    }

    final id = _toInt(task['id']);

    if (id == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AdminTaskDetailSheet(
        taskId: id,
        service: _service,
        onChanged: _load,
      ),
    );
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    if (!_admin) {
      return;
    }

    final id = _toInt(task['id']);

    if (id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Tanod Task'),
          content: Text(
            'Delete "${_text(task['title'], 'this task')}"? '
            'Its task responses and tanod-task notifications will also be removed.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final response = await _service.deleteTask(id);

      if (!mounted) {
        return;
      }

      _show(
        response['message']?.toString() ?? 'Tanod task deleted successfully.',
      );
      await _load();
    } on AuthException catch (exception) {
      _show(exception.message);
    }
  }

  Future<void> _respond(Map<String, dynamic> response, String decision) async {
    if (!_tanod) {
      return;
    }

    final responseId = _toInt(response['id']);

    if (responseId == null) {
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RespondSheet(
        service: _service,
        responseId: responseId,
        decision: decision,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    _show(result);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!(_admin || _tanod)) {
      return _StateCard(
        icon: Icons.lock_outline_rounded,
        message: _error ?? 'Tanod Tasks is unavailable.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: <Widget>[
          _buildHeader(context),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 90),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _StateCard(
              icon: Icons.error_outline_rounded,
              message: _error!,
              actionLabel: 'Try Again',
              onAction: _load,
            )
          else if (_items.isEmpty)
            _StateCard(
              icon: Icons.assignment_outlined,
              message: _admin
                  ? 'No tanod tasks yet. Create a task so tanods can accept or decline it.'
                  : 'No tasks assigned. New tanod tasks will appear here once admin creates one.',
            )
          else ...<Widget>[
            if (_admin)
              for (final task in _items) ...<Widget>[
                _AdminTaskCard(
                  task: task,
                  onView: () => _showTaskDetails(task),
                  onDelete: () => _deleteTask(task),
                ),
                const SizedBox(height: 12),
              ]
            else
              for (final response in _items) ...<Widget>[
                _TanodTaskCard(
                  response: response,
                  onAccept: () => _respond(response, 'accepted'),
                  onDecline: () => _respond(response, 'declined'),
                ),
                const SizedBox(height: 12),
              ],
            if (_currentPage < _lastPage)
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

  Widget _buildHeader(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
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
            _admin ? 'Tanod Tasks' : 'My Assigned Tasks',
            style: TextStyle(
              color: palette.textMain,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _admin
                ? 'Create tasks for tanods and monitor who accepted, declined, or has not responded yet.'
                : 'Review tasks assigned by the admin and submit whether you accept or decline.',
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (_admin) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Active tanods who receive new tasks: '
              '${_toInt(_summary['active_tanod_count']) ?? 0}',
              style: TextStyle(
                color: palette.accentText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _permissions['can_create'] == false
                    ? null
                    : _createTask,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Task'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _show(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AdminTaskCard extends StatelessWidget {
  const _AdminTaskCard({
    required this.task,
    required this.onView,
    required this.onDelete,
  });

  final Map<String, dynamic> task;
  final VoidCallback onView;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);
    final status = _text(task['status'], 'open').toLowerCase();
    final priority = _text(task['priority'], 'normal').toLowerCase();

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
                child: Text(
                  _text(task['title'], 'Untitled Task'),
                  style: TextStyle(
                    color: palette.textMain,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(value: status, label: _humanize(status)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _text(task['description'], 'No description provided.'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (_nullableText(task['location']) != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Location: ${task['location']}',
              style: TextStyle(
                color: palette.textSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (_nullableText(task['barangay_name']) != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Response Barangay: ${task['barangay_name']}',
              style: TextStyle(
                color: palette.textSoft,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (task['fallback_used'] == true) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Fallback routing used because no active tanod was available in the selected barangay.',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _PriorityBadge(priority),
              _InfoPill(
                label: 'Accepted',
                value: _numberText(task['accepted_responses_count']),
              ),
              _InfoPill(
                label: 'Declined',
                value: _numberText(task['declined_responses_count']),
              ),
              _InfoPill(
                label: 'Pending',
                value: _numberText(task['pending_responses_count']),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ScheduleBlock(task: task),
          const SizedBox(height: 14),
          Divider(color: palette.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: onView,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View'),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Delete task',
                onPressed: onDelete,
                color: const Color(0xFFDC2626),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TanodTaskCard extends StatelessWidget {
  const _TanodTaskCard({
    required this.response,
    required this.onAccept,
    required this.onDecline,
  });

  final Map<String, dynamic> response;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);
    final task = _map(response['task']);
    final responseStatus = _text(
      response['response_status'],
      'pending',
    ).toLowerCase();
    final taskStatus = _text(task['status'], 'unknown').toLowerCase();
    final canRespond = response['can_respond'] == true;

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
          Wrap(
            spacing: 7,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                _text(task['title'], 'Untitled Task'),
                style: TextStyle(
                  color: palette.textMain,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              _ResponseBadge(responseStatus),
              _StatusBadge(
                value: taskStatus,
                label: switch (taskStatus) {
                  'open' => 'Task Open',
                  'closed' => 'Task Closed',
                  'cancelled' => 'Task Cancelled',
                  _ => 'Task ${_humanize(taskStatus)}',
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _text(task['description'], 'No description provided.'),
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (_nullableText(task['barangay_name']) != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Response Barangay: ${task['barangay_name']}',
              style: TextStyle(
                color: palette.textSoft,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _ScheduleBlock(task: task),
          if (_nullableText(response['responded_at']) != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Responded: ${_formatDateTime(response['responded_at'])}',
              style: TextStyle(color: palette.textMuted, fontSize: 12),
            ),
          ],
          if (_nullableText(response['response_note']) != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'YOUR NOTE',
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    response['response_note'].toString(),
                    style: TextStyle(color: palette.textSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (canRespond)
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onAccept,
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB91C1C),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onDecline,
                    child: const Text('Decline'),
                  ),
                ),
              ],
            )
          else
            _FinalResponseMessage(
              responseStatus: responseStatus,
              taskStatus: taskStatus,
            ),
        ],
      ),
    );
  }
}

class _CreateTaskSheet extends StatefulWidget {
  const _CreateTaskSheet({
    required this.service,
    required this.activeTanodCount,
    required this.barangayOptions,
  });

  final TanodTaskService service;
  final int activeTanodCount;
  final List<Map<String, dynamic>> barangayOptions;

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _location = TextEditingController();

  String _priority = 'normal';
  int? _barangayId;
  DateTime? _taskDateTime;
  DateTime? _dueAt;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final base = initial ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (date == null || !mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );

    if (time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }

    if (_barangayId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Response barangay is required.')),
        );
      return;
    }

    if (_taskDateTime != null &&
        _dueAt != null &&
        _dueAt!.isBefore(_taskDateTime!)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Response due date/time cannot be earlier than the task date/time.',
            ),
          ),
        );
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final response = await widget.service.createTask(
        title: _title.text,
        description: _description.text,
        location: _location.text,
        barangayId: _barangayId!,
        taskDateTime: _taskDateTime,
        dueAt: _dueAt,
        priority: _priority,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        response['message']?.toString() ?? 'Tanod task created successfully.',
      );
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(exception.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: palette.surface,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 22 + inset),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Create Tanod Task',
                      style: TextStyle(
                        color: palette.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tanods assigned to the selected barangay receive this task first. If none are available, active tanods from other Dao barangays are used as fallback.',
                style: TextStyle(color: palette.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Task Title *',
                  hintText: 'Example: Night patrol at Barangay Poblacion',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Task title is required.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Explain the task details...',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _barangayId,
                decoration: const InputDecoration(
                  labelText: 'Response Barangay *',
                  helperText:
                      'Tanods assigned to this barangay are offered the task first.',
                ),
                items: widget.barangayOptions
                    .map(
                      (row) {
                        final id = _toInt(row['value'] ?? row['id']);
                        final label =
                            row['label']?.toString().trim().isNotEmpty == true
                            ? row['label'].toString().trim()
                            : row['barangay_name']?.toString().trim() ?? '';

                        if (id == null || label.isEmpty) {
                          return null;
                        }

                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(label),
                        );
                      },
                    )
                    .whereType<DropdownMenuItem<int>>()
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) {
                        setState(() {
                          _barangayId = value;
                        });
                      },
                validator: (value) =>
                    value == null ? 'Response barangay is required.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'Street, sitio, landmark, or exact area',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _priority = value;
                          });
                        }
                      },
              ),
              const SizedBox(height: 12),
              _DateTimeField(
                label: 'Task Date / Time',
                value: _taskDateTime,
                onTap: () async {
                  final value = await _pickDateTime(_taskDateTime);

                  if (value != null && mounted) {
                    setState(() {
                      _taskDateTime = value;
                    });
                  }
                },
                onClear: _taskDateTime == null
                    ? null
                    : () {
                        setState(() {
                          _taskDateTime = null;
                        });
                      },
              ),
              const SizedBox(height: 12),
              _DateTimeField(
                label: 'Response Due Date / Time',
                value: _dueAt,
                onTap: () async {
                  final value = await _pickDateTime(_dueAt ?? _taskDateTime);

                  if (value != null && mounted) {
                    setState(() {
                      _dueAt = value;
                    });
                  }
                },
                onClear: _dueAt == null
                    ? null
                    : () {
                        setState(() {
                          _dueAt = null;
                        });
                      },
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Active tanods across Dao: ${widget.activeTanodCount}. '
                  'Routing starts with the selected barangay before fallback.',
                  style: TextStyle(
                    color: palette.accentText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create Task'),
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

class _AdminTaskDetailSheet extends StatefulWidget {
  const _AdminTaskDetailSheet({
    required this.taskId,
    required this.service,
    required this.onChanged,
  });

  final int taskId;
  final TanodTaskService service;
  final Future<void> Function() onChanged;

  @override
  State<_AdminTaskDetailSheet> createState() => _AdminTaskDetailSheetState();
}

class _AdminTaskDetailSheetState extends State<_AdminTaskDetailSheet> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic> _task = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await widget.service.taskDetails(widget.taskId);

      if (!mounted) {
        return;
      }

      setState(() {
        _task = _map(response['data']);
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
    }
  }

  Future<void> _transition(String action) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final response = action == 'close'
          ? await widget.service.closeTask(widget.taskId)
          : await widget.service.cancelTask(widget.taskId);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(response['message']?.toString() ?? 'Task updated.'),
          ),
        );

      await widget.onChanged();
      await _load();

      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(exception.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);
    final responses = _mapList(_task['responses']);
    final status = _text(_task['status'], 'unknown').toLowerCase();

    return Material(
      color: palette.surface,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _StateCard(
              icon: Icons.error_outline_rounded,
              message: _error!,
              actionLabel: 'Try Again',
              onAction: _load,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _text(_task['title'], 'Tanod Task'),
                        style: TextStyle(
                          color: palette.textMain,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusBadge(value: status, label: _humanize(status)),
                ),
                const SizedBox(height: 14),
                Text(
                  _text(_task['description'], 'No description provided.'),
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                if (_nullableText(_task['barangay_name']) != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'Response Barangay: ${_task['barangay_name']}',
                    style: TextStyle(
                      color: palette.textSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (_task['fallback_used'] == true) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Fallback routing was used for this task.',
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: <Widget>[
                    _MetricCard(
                      label: 'Total Tanods',
                      value: _numberText(_task['responses_count']),
                    ),
                    _MetricCard(
                      label: 'Accepted',
                      value: _numberText(_task['accepted_responses_count']),
                    ),
                    _MetricCard(
                      label: 'Declined',
                      value: _numberText(_task['declined_responses_count']),
                    ),
                    _MetricCard(
                      label: 'Pending',
                      value: _numberText(_task['pending_responses_count']),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ScheduleBlock(task: _task),
                if (status == 'open') ...<Widget>[
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _transition('close'),
                          child: const Text('Close Task'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB91C1C),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _busy ? null : () => _transition('cancel'),
                          child: const Text('Cancel Task'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  'Tanod Responses',
                  style: TextStyle(
                    color: palette.textMain,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Shows who accepted, declined, or has not responded.',
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (responses.isEmpty)
                  Text(
                    'No response records.',
                    style: TextStyle(color: palette.textMuted),
                  )
                else
                  for (final response in responses) ...<Widget>[
                    _ResponseRow(response: response),
                    const SizedBox(height: 9),
                  ],
              ],
            ),
    );
  }
}

class _RespondSheet extends StatefulWidget {
  const _RespondSheet({
    required this.service,
    required this.responseId,
    required this.decision,
  });

  final TanodTaskService service;
  final int responseId;
  final String decision;

  @override
  State<_RespondSheet> createState() => _RespondSheetState();
}

class _RespondSheetState extends State<_RespondSheet> {
  final TextEditingController _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final response = await widget.service.respond(
        responseId: widget.responseId,
        responseStatus: widget.decision,
        responseNote: _note.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        response['message']?.toString() ??
            'Task response submitted successfully.',
      );
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(exception.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);
    final accepting = widget.decision == 'accepted';
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: palette.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 20 + inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              accepting ? 'Accept Task' : 'Decline Task',
              style: TextStyle(
                color: palette.textMain,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Your response is final once submitted.',
              style: TextStyle(color: palette.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Note / Reason',
                hintText: 'Optional note...',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accepting
                      ? const Color(0xFF15803D)
                      : const Color(0xFFB91C1C),
                  foregroundColor: Colors.white,
                ),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(accepting ? 'Confirm Accept' : 'Confirm Decline'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_rounded),
                ),
              const Icon(Icons.calendar_month_rounded),
              const SizedBox(width: 12),
            ],
          ),
        ),
        child: Text(value == null ? 'Not set' : _formatLocalDateTime(value!)),
      ),
    );
  }
}

class _ScheduleBlock extends StatelessWidget {
  const _ScheduleBlock({required this.task});

  final Map<String, dynamic> task;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _InfoBox(
          label: 'Location',
          value: _text(task['location'], 'No location'),
        ),
        _InfoBox(
          label: 'Schedule',
          value: _formatDateTime(
            task['task_datetime'],
            fallback: 'No schedule',
          ),
        ),
        _InfoBox(
          label: 'Response Due',
          value: _formatDateTime(task['due_at'], fallback: 'No due date'),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: palette.textSoft,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      width: 145,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: palette.textMain,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponseRow extends StatelessWidget {
  const _ResponseRow({required this.response});

  final Map<String, dynamic> response;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);
    final status = _text(response['response_status'], 'pending').toLowerCase();

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _text(response['tanod_name'], 'Tanod'),
                  style: TextStyle(
                    color: palette.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _ResponseBadge(status),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Employee ID: ${response['employee_id'] ?? '—'}',
            style: TextStyle(color: palette.textMuted, fontSize: 11),
          ),
          if (_nullableText(response['response_note']) != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              response['response_note'].toString(),
              style: TextStyle(color: palette.textSoft, fontSize: 12),
            ),
          ],
          const SizedBox(height: 5),
          Text(
            _formatDateTime(
              response['responded_at'],
              fallback: 'Not yet responded',
            ),
            style: TextStyle(color: palette.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge(this.priority);

  final String priority;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final (background, foreground) = switch (priority) {
      'urgent' => (
        palette.isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
        palette.isDark ? const Color(0xFFFECACA) : const Color(0xFFB91C1C),
      ),
      'high' => (
        palette.isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5),
        palette.isDark ? const Color(0xFFFED7AA) : const Color(0xFFC2410C),
      ),
      'low' => (palette.surfaceSoft, palette.textSoft),
      _ => (palette.accentSoft, palette.accentText),
    };

    return _Badge(
      label: _humanize(priority),
      background: background,
      foreground: foreground,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final (background, foreground) = switch (value) {
      'open' => (
        palette.isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
        palette.isDark ? const Color(0xFFBBF7D0) : const Color(0xFF15803D),
      ),
      'cancelled' || 'canceled' => (
        palette.isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
        palette.isDark ? const Color(0xFFFECACA) : const Color(0xFFB91C1C),
      ),
      _ => (palette.surfaceSoft, palette.textSoft),
    };

    return _Badge(label: label, background: background, foreground: foreground);
  }
}

class _ResponseBadge extends StatelessWidget {
  const _ResponseBadge(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final (background, foreground) = switch (status) {
      'accepted' => (
        palette.isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
        palette.isDark ? const Color(0xFFBBF7D0) : const Color(0xFF15803D),
      ),
      'declined' || 'rejected' => (
        palette.isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
        palette.isDark ? const Color(0xFFFECACA) : const Color(0xFFB91C1C),
      ),
      _ => (
        palette.isDark ? const Color(0xFF713F12) : const Color(0xFFFEF9C3),
        palette.isDark ? const Color(0xFFFEF08A) : const Color(0xFFA16207),
      ),
    };

    return _Badge(
      label: _humanize(status),
      background: background,
      foreground: foreground,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: palette.textSoft,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FinalResponseMessage extends StatelessWidget {
  const _FinalResponseMessage({
    required this.responseStatus,
    required this.taskStatus,
  });

  final String responseStatus;
  final String taskStatus;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    final text = switch (responseStatus) {
      'accepted' => 'You accepted this task. No further response is needed.',
      'declined' ||
      'rejected' => 'You declined this task. No further response is needed.',
      _ when taskStatus != 'open' =>
        'This task is no longer open for response.',
      _ => 'Response already submitted.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: palette.textSoft,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: palette.textMuted, size: 34),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSoft, fontSize: 13),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
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

int? _toInt(Object? value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '');
}

String _text(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String _numberText(Object? value) {
  return (_toInt(value) ?? 0).toString();
}

String _humanize(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _formatDateTime(Object? value, {String fallback = '—'}) {
  final raw = value?.toString().trim() ?? '';

  if (raw.isEmpty) {
    return fallback;
  }

  final parsed = DateTime.tryParse(raw);

  if (parsed == null) {
    return raw;
  }

  return _formatLocalDateTime(parsed.toLocal());
}

String _formatLocalDateTime(DateTime value) {
  const months = <String>[
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

  final hour12 = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;

  final minute = value.minute.toString().padLeft(2, '0');
  final amPm = value.hour >= 12 ? 'PM' : 'AM';

  return '${months[value.month - 1]} '
      '${value.day.toString().padLeft(2, '0')}, '
      '${value.year} '
      '$hour12:$minute $amPm';
}
