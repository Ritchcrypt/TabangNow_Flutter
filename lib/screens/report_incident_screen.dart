import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/tabangnow_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/auth_service.dart';
import '../services/incident_service.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({
    super.key,
    required this.incidentService,
    required this.user,
  });

  final IncidentService incidentService;
  final Map<String, dynamic> user;

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  static const LatLng _daoCenter = LatLng(11.3945, 122.6858);
  static const String _osmUserAgentPackage = 'com.example.tabangnow_flutter';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _mapSearchController = TextEditingController();
  final TextEditingController _barangayNameController = TextEditingController();
  final MapController _mapController = MapController();

  bool _loading = true;
  bool _submitting = false;
  bool _mapSearching = false;
  bool _showAddBarangayPanel = false;
  bool _addingBarangay = false;
  String? _barangayAddError;
  String? _error;
  String _mapStatus = 'Search results will automatically move the map pin.';

  List<Map<String, dynamic>> _categories = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _barangays = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _severities = <Map<String, dynamic>>[];
  List<PlatformFile> _evidence = <PlatformFile>[];

  List<String> _allowedExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
  ];

  Map<String, dynamic> _submissionInfo = <String, dynamic>{};
  Map<String, dynamic> _permissions = <String, dynamic>{};

  int _maxFiles = 5;
  int _maxKilobytesEach = 10240;
  int? _categoryId;
  int? _barangayId;
  String? _priority;
  LatLng? _selectedPoint;

  DateTime? _lastMapSearchAt;
  final Map<String, _MapSearchResult> _mapCache = <String, _MapSearchResult>{};

  bool get _canManageBarangays => _permissions['can_manage_barangays'] == true;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _mapSearchController.dispose();
    _barangayNameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions({bool keepSelections = true}) async {
    try {
      final response = await widget.incidentService.incidentOptions();
      final data = _map(response['data']);
      final evidencePolicy = _map(data['evidence']);

      if (!mounted) {
        return;
      }

      final oldCategory = _categoryId;
      final oldBarangay = _barangayId;
      final oldPriority = _priority;

      setState(() {
        _categories = _mapList(data['categories']);
        _barangays = _mapList(data['barangays']);
        _severities = _mapList(data['severity_options']);
        _submissionInfo = _map(data['submission_info']);
        _permissions = _map(data['permissions']);

        _maxFiles = _toInt(evidencePolicy['max_files']) ?? 5;
        _maxKilobytesEach =
            _toInt(evidencePolicy['max_kilobytes_each']) ?? 10240;

        final rawExtensions = evidencePolicy['allowed_extensions'];

        if (rawExtensions is List && rawExtensions.isNotEmpty) {
          _allowedExtensions = rawExtensions
              .map((item) => item.toString().toLowerCase())
              .toList();
        }

        if (keepSelections) {
          _categoryId = _containsId(_categories, oldCategory)
              ? oldCategory
              : null;
          _barangayId = _containsId(_barangays, oldBarangay)
              ? oldBarangay
              : null;
          _priority = _containsValue(_severities, oldPriority)
              ? oldPriority
              : null;
        }

        _loading = false;
        _error = null;
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
        _error = 'Unable to load incident form options.';
      });
    }
  }

  void _toggleAddBarangayPanel() {
    if (_addingBarangay) {
      return;
    }

    setState(() {
      _showAddBarangayPanel = !_showAddBarangayPanel;
      _barangayAddError = null;

      if (!_showAddBarangayPanel) {
        _barangayNameController.clear();
      }
    });
  }

  Future<void> _saveBarangay() async {
    if (_addingBarangay) {
      return;
    }

    final name = _barangayNameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _barangayAddError = 'Enter a barangay name first.';
      });
      return;
    }

    if (name.length > 255) {
      setState(() {
        _barangayAddError = 'Barangay name must not exceed 255 characters.';
      });
      return;
    }

    setState(() {
      _addingBarangay = true;
      _barangayAddError = null;
    });

    try {
      final response = await widget.incidentService.addBarangay(name: name);
      final created = _map(response['data']);
      final createdId = _toInt(created['id']);

      await _loadOptions();

      if (!mounted) {
        return;
      }

      final createdIsAvailable =
          createdId != null && _containsId(_barangays, createdId);

      setState(() {
        _addingBarangay = false;
        _showAddBarangayPanel = false;
        _barangayAddError = null;
        _barangayNameController.clear();

        if (createdIsAvailable) {
          _barangayId = createdId;
        }
      });

      _showMessage(
        response['message']?.toString() ?? 'Barangay added successfully.',
      );
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _addingBarangay = false;
        _barangayAddError = exception.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _addingBarangay = false;
        _barangayAddError =
            'Unable to add barangay right now. Please try again.';
      });
    }
  }

  Future<void> _removeBarangay() async {
    if (_barangays.isEmpty) {
      _showMessage('No barangays are available.');
      return;
    }

    int? selectedId;

    final barangayId = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Remove Barangay'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Barangays already used by system records cannot be removed.',
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: selectedId,
                    decoration: const InputDecoration(
                      labelText: 'Barangay',
                      border: OutlineInputBorder(),
                    ),
                    items: _barangays
                        .map((item) {
                          final id = _toInt(item['id']);

                          if (id == null) {
                            return null;
                          }

                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(item['name']?.toString() ?? 'Barangay'),
                          );
                        })
                        .whereType<DropdownMenuItem<int>>()
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedId = value;
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                  ),
                  onPressed: selectedId == null
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(selectedId);
                        },
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        );
      },
    );

    if (barangayId == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: const Text(
          'Remove this barangay? The server will block removal '
          'if any system record already references it.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final response = await widget.incidentService.deleteBarangay(
        barangayId: barangayId,
      );

      if (_barangayId == barangayId) {
        _barangayId = null;
      }

      await _loadOptions();

      if (mounted) {
        _showMessage(
          response['message']?.toString() ?? 'Barangay removed successfully.',
        );
      }
    } on AuthException catch (exception) {
      if (mounted) {
        _showMessage(exception.message);
      }
    }
  }

  Future<void> _pickEvidence() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final combined = <PlatformFile>[..._evidence, ...result.files];

    if (combined.length > _maxFiles) {
      _showMessage('Maximum $_maxFiles evidence files are allowed.');
      return;
    }

    final maximumBytes = _maxKilobytesEach * 1024;

    for (final file in combined) {
      if (file.size > maximumBytes) {
        _showMessage(
          '${file.name} exceeds '
          '${_maxKilobytesEach ~/ 1024} MB.',
        );
        return;
      }

      final extension = file.extension?.trim().toLowerCase() ?? '';

      if (!_allowedExtensions.contains(extension)) {
        _showMessage('${file.name} is not an allowed evidence type.');
        return;
      }
    }

    setState(() {
      _evidence = combined;
    });
  }

  void _removeEvidence(PlatformFile file) {
    setState(() {
      _evidence = List<PlatformFile>.from(_evidence)..remove(file);
    });
  }

  void _placePin(
    LatLng point, {
    String message = 'Map pin placed manually.',
    bool moveMap = false,
  }) {
    setState(() {
      _selectedPoint = point;
      _mapStatus = message;
    });

    if (moveMap) {
      _mapController.move(point, 17);
    }
  }

  void _clearPin() {
    setState(() {
      _selectedPoint = null;
      _mapStatus = 'Map pin cleared.';
    });
  }

  Future<void> _searchMap() async {
    if (_mapSearching) {
      return;
    }

    final rawQuery = _mapSearchController.text.trim();

    if (rawQuery.isEmpty) {
      setState(() {
        _mapStatus = 'Type a place, road, landmark, or barangay first.';
      });
      return;
    }

    final cacheKey = rawQuery.toLowerCase();
    final cached = _mapCache[cacheKey];

    if (cached != null) {
      _placePin(
        cached.point,
        message: 'Location found and pin was placed.',
        moveMap: true,
      );
      return;
    }

    setState(() {
      _mapSearching = true;
      _mapStatus = 'Searching map location...';
    });

    try {
      final previous = _lastMapSearchAt;

      if (previous != null) {
        final elapsed = DateTime.now().difference(previous);

        if (elapsed < const Duration(seconds: 1)) {
          await Future<void>.delayed(const Duration(seconds: 1) - elapsed);
        }
      }

      _lastMapSearchAt = DateTime.now();

      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        <String, String>{
          'format': 'jsonv2',
          'limit': '1',
          'q': '$rawQuery, Dao, Capiz, Philippines',
        },
      );

      final response = await http
          .get(
            uri,
            headers: const <String, String>{
              'Accept': 'application/json',
              'User-Agent':
                  'TabangNowMobile/1.0 '
                  '(com.example.tabangnow_flutter)',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Map search failed.');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! List || decoded.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _mapSearching = false;
          _mapStatus =
              'No map result found. Try a nearby landmark '
              'or barangay name.';
        });
        return;
      }

      final raw = decoded.first;

      if (raw is! Map) {
        throw Exception('Invalid map result.');
      }

      final item = Map<String, dynamic>.from(raw);
      final latitude = double.tryParse(item['lat']?.toString() ?? '');
      final longitude = double.tryParse(item['lon']?.toString() ?? '');

      if (latitude == null || longitude == null) {
        throw Exception('Invalid map coordinates.');
      }

      final result = _MapSearchResult(
        point: LatLng(latitude, longitude),
        displayName: item['display_name']?.toString() ?? rawQuery,
      );

      _mapCache[cacheKey] = result;

      if (!mounted) {
        return;
      }

      setState(() {
        _mapSearching = false;
      });

      _placePin(
        result.point,
        message:
            'Location found and pin was placed.\n'
            '${result.displayName}',
        moveMap: true,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _mapSearching = false;
        _mapStatus =
            'Map search failed. Check your internet '
            'connection and try again.';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_categoryId == null || _barangayId == null || _priority == null) {
      setState(() {
        _error = 'Select a category, barangay, and severity.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.incidentService.createIncident(
        title: _titleController.text,
        description: _descriptionController.text,
        categoryId: _categoryId!,
        barangayId: _barangayId!,
        priority: _priority!,
        locationAddress: _locationController.text,
        latitude: _selectedPoint?.latitude,
        longitude: _selectedPoint?.longitude,
        evidence: _evidence,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incident report submitted successfully.'),
        ),
      );

      Navigator.of(context).pop(true);
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
        _error = exception.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
        _error = 'Unable to submit the incident report.';
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabangNowTheme.of(context).pageBackground,
      appBar: AppBar(
        title: const Text('Report Incident'),
        backgroundColor: TabangNowTheme.of(context).surface,
        surfaceTintColor: TabangNowTheme.of(context).surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null && _categories.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const SizedBox(height: 90),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _loadOptions,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ),
        ],
      );
    }

    final reporter = _map(_submissionInfo['reporter']);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: <Widget>[
          const _PageIntro(),
          const SizedBox(height: 16),
          _FormSection(
            title: 'Incident Details',
            subtitle: 'Describe what happened clearly and accurately.',
            child: _incidentFields(),
          ),
          const SizedBox(height: 16),
          _FormSection(
            title: 'Location',
            subtitle:
                'Provide the barangay, exact landmark, and '
                'search or pin the location on the map.',
            child: _locationFields(),
          ),
          const SizedBox(height: 16),
          _FormSection(
            title: 'Upload Evidence',
            subtitle:
                'Optional. Maximum $_maxFiles files. '
                'JPG, JPEG, PNG, WEBP, or PDF only. '
                'Max ${_maxKilobytesEach ~/ 1024} MB each.',
            child: _evidenceFields(),
          ),
          const SizedBox(height: 16),
          _SubmissionInfo(
            reporterName:
                reporter['name']?.toString() ??
                widget.user['name']?.toString() ??
                'User',
            initialStatus:
                _submissionInfo['initial_status']?.toString() ?? 'Reported',
            date: _formatLongDate(
              _parseDate(_submissionInfo['date']) ?? DateTime.now(),
            ),
          ),
          const SizedBox(height: 16),
          const _ReminderCard(),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 16),
            _ValidationError(message: _error!),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _submitting ? 'Submitting...' : 'Submit Incident Report',
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _submitting
                  ? null
                  : () {
                      Navigator.of(context).pop(false);
                    },
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _incidentFields() {
    return Column(
      children: <Widget>[
        TextFormField(
          controller: _titleController,
          maxLength: 255,
          decoration: const InputDecoration(
            labelText: 'Incident Title',
            hintText: 'Example: Road accident near public market',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';

            if (text.isEmpty) {
              return 'Incident title is required.';
            }

            if (text.length > 255) {
              return 'Incident title must not exceed 255 characters.';
            }

            return null;
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _categoryId,
          decoration: const InputDecoration(
            labelText: 'Incident Category',
            border: OutlineInputBorder(),
          ),
          items: _categories
              .map((item) {
                final id = _toInt(item['id']);

                if (id == null) {
                  return null;
                }

                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(item['name']?.toString() ?? 'Category'),
                );
              })
              .whereType<DropdownMenuItem<int>>()
              .toList(),
          onChanged: (value) {
            setState(() {
              _categoryId = value;
            });
          },
          validator: (value) => value == null ? 'Select a category.' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _priority,
          decoration: const InputDecoration(
            labelText: 'Severity',
            border: OutlineInputBorder(),
          ),
          items: _severities
              .map((item) {
                final value = item['value']?.toString().trim();

                if (value == null || value.isEmpty) {
                  return null;
                }

                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(item['label']?.toString() ?? value),
                );
              })
              .whereType<DropdownMenuItem<String>>()
              .toList(),
          onChanged: (value) {
            setState(() {
              _priority = value;
            });
          },
          validator: (value) => value == null ? 'Select a severity.' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          minLines: 6,
          maxLines: 9,
          maxLength: 3000,
          decoration: const InputDecoration(
            labelText: 'Description',
            alignLabelWithHint: true,
            hintText:
                'Describe what happened, who was involved, '
                'visible danger, injuries, damage, or other '
                'important details...',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';

            if (text.isEmpty) {
              return 'Description is required.';
            }

            if (text.length > 3000) {
              return 'Description must not exceed 3000 characters.';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _locationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_canManageBarangays) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addingBarangay ? null : _toggleAddBarangayPanel,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Barangay'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _removeBarangay,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                  ),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Remove'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_canManageBarangays && _showAddBarangayPanel) ...<Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _barangayNameController,
                  autofocus: true,
                  maxLength: 255,
                  textInputAction: TextInputAction.done,
                  enabled: !_addingBarangay,
                  onChanged: (_) {
                    if (_barangayAddError != null) {
                      setState(() {
                        _barangayAddError = null;
                      });
                    }
                  },
                  onSubmitted: (_) {
                    if (!_addingBarangay) {
                      _saveBarangay();
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Barangay Name',
                    hintText: 'Enter barangay name',
                    errorText: _barangayAddError,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _addingBarangay ? null : _saveBarangay,
                    icon: _addingBarangay
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _addingBarangay ? 'Saving...' : 'Save Barangay',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<int>(
          key: ValueKey<int?>(_barangayId),

          initialValue: _barangayId,
          decoration: const InputDecoration(
            labelText: 'Barangay',
            border: OutlineInputBorder(),
          ),
          items: _barangays
              .map((item) {
                final id = _toInt(item['id']);

                if (id == null) {
                  return null;
                }

                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(item['name']?.toString() ?? 'Barangay'),
                );
              })
              .whereType<DropdownMenuItem<int>>()
              .toList(),
          onChanged: (value) {
            setState(() {
              _barangayId = value;
            });
          },
          validator: (value) => value == null ? 'Select a barangay.' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _locationController,
          minLines: 4,
          maxLines: 5,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Exact Location / Landmark',
            alignLabelWithHint: true,
            hintText:
                'Example: Near Dao Public Market, beside '
                'the tricycle terminal...',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';

            if (text.isEmpty) {
              return 'Incident location is required.';
            }

            if (text.length > 500) {
              return 'Location must not exceed 500 characters.';
            }

            return null;
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _mapSearchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _searchMap(),
          decoration: InputDecoration(
            labelText: 'Search Location on Map',
            hintText: 'Search place, road, landmark, or barangay...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              onPressed: _mapSearching ? null : _searchMap,
              icon: _mapSearching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _mapStatus,
                style: TextStyle(
                  color: TabangNowTheme.of(context).textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            if (_selectedPoint != null)
              TextButton(onPressed: _clearPin, child: const Text('Clear Pin')),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 360,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _daoCenter,
                initialZoom: 14,
                onTap: (_, point) {
                  _placePin(point);
                },
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: _osmUserAgentPackage,
                ),
                if (_selectedPoint != null)
                  MarkerLayer(
                    markers: <Marker>[
                      Marker(
                        point: _selectedPoint!,
                        width: 38,
                        height: 38,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF172554),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x660F172A),
                                blurRadius: 12,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                const RichAttributionWidget(
                  attributions: <SourceAttribution>[
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_selectedPoint != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            'Coordinates: '
            '${_selectedPoint!.latitude.toStringAsFixed(7)}, '
            '${_selectedPoint!.longitude.toStringAsFixed(7)}',
            style: const TextStyle(
              color: Color(0xFF1E40AF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _evidenceFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _submitting ? null : _pickEvidence,
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(
              _evidence.isEmpty
                  ? 'Choose Evidence'
                  : 'Add More Evidence '
                        '(${_evidence.length}/$_maxFiles)',
            ),
          ),
        ),
        if (_evidence.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          ..._evidence.map(
            (file) => _SelectedEvidenceCard(
              file: file,
              onRemove: () => _removeEvidence(file),
            ),
          ),
        ],
      ],
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  static int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static bool _containsId(List<Map<String, dynamic>> items, int? id) {
    if (id == null) {
      return false;
    }

    return items.any((item) => _toInt(item['id']) == id);
  }

  static bool _containsValue(List<Map<String, dynamic>> items, String? value) {
    if (value == null) {
      return false;
    }

    return items.any((item) => item['value']?.toString() == value);
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'INCIDENT REPORTING',
            style: TextStyle(
              color: Color(0xFF1D4ED8),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Report New Incident',
            style: TextStyle(
              color: TabangNowTheme.of(context).textMain,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Submit a real community safety incident report '
            'for review and response by authorized personnel.',
            style: TextStyle(
              color: TabangNowTheme.of(context).textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: TabangNowTheme.of(context).textMain,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: TabangNowTheme.of(context).textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _SelectedEvidenceCard extends StatelessWidget {
  const _SelectedEvidenceCard({required this.file, required this.onRemove});

  final PlatformFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final extension = file.extension?.toLowerCase() ?? '';
    final isImage = <String>['jpg', 'jpeg', 'png', 'webp'].contains(extension);

    Widget preview;

    if (isImage && file.path != null && file.path!.isNotEmpty) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(file.path!),
          width: 76,
          height: 76,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.image_not_supported_outlined, size: 36),
        ),
      );
    } else {
      preview = Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: TabangNowTheme.of(context).surfaceSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          extension == 'pdf'
              ? Icons.picture_as_pdf_outlined
              : Icons.insert_drive_file_outlined,
          size: 34,
          color: TabangNowTheme.of(context).textSoft,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TabangNowTheme.of(context).surfaceMuted,
        border: Border.all(color: TabangNowTheme.of(context).border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          preview,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: TabangNowTheme.of(context).textMain,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatBytes(file.size),
                  style: TextStyle(
                    color: TabangNowTheme.of(context).textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove evidence',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _SubmissionInfo extends StatelessWidget {
  const _SubmissionInfo({
    required this.reporterName,
    required this.initialStatus,
    required this.date,
  });

  final String reporterName;
  final String initialStatus;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text(
              'Submission Info',
              style: TextStyle(
                color: TabangNowTheme.of(context).textMain,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                _InfoLine(label: 'Reporter', value: reporterName),
                const SizedBox(height: 14),
                _InfoLine(label: 'Initial Status', value: initialStatus),
                const SizedBox(height: 14),
                _InfoLine(label: 'Date', value: date),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 110,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: TabangNowTheme.of(context).textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: TabangNowTheme.of(context).textMain,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Reminder',
            style: TextStyle(
              color: Color(0xFF1E3A8A),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Submit only real and accurate incident information. '
            'False or misleading reports may delay emergency response.',
            style: TextStyle(color: Color(0xFF1E40AF), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ValidationError extends StatelessWidget {
  const _ValidationError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB91C1C),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MapSearchResult {
  const _MapSearchResult({required this.point, required this.displayName});

  final LatLng point;
  final String displayName;
}

DateTime? _parseDate(Object? value) {
  final raw = value?.toString().trim();

  if (raw == null || raw.isEmpty) {
    return null;
  }

  return DateTime.tryParse(raw)?.toLocal();
}

String _formatLongDate(DateTime date) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${months[date.month - 1]} '
      '${date.day.toString().padLeft(2, '0')}, '
      '${date.year}';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }

  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

BoxDecoration _panelDecoration(BuildContext context) {
  return BoxDecoration(
    color: TabangNowTheme.of(context).surface,
    border: Border.all(color: TabangNowTheme.of(context).border),
    borderRadius: BorderRadius.circular(16),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );
}
