import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/tabangnow_theme.dart';
import '../services/resident_complaint_service.dart';
import 'photo_capture_screen.dart';

class ResidentComplaintCreateScreen extends StatefulWidget {
  const ResidentComplaintCreateScreen({
    super.key,
    required this.service,
    required this.user,
  });

  final ResidentComplaintService service;
  final Map<String, dynamic> user;

  @override
  State<ResidentComplaintCreateScreen> createState() =>
      _ResidentComplaintCreateScreenState();
}

class _ResidentComplaintCreateScreenState
    extends State<ResidentComplaintCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;

  final _contactController = TextEditingController();

  final _subjectController = TextEditingController();

  final _addressController = TextEditingController();

  final _descriptionController = TextEditingController();

  PlatformFile? _evidence;
  bool _saving = false;

  String _feedbackCategory = 'community_concern';
  String _feedbackType = 'concern';
  int? _serviceRating;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.user['name']?.toString().trim() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _subjectController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
    );

    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    _setEvidence(result.files.single);
  }

  Future<void> _takeEvidencePhoto() async {
    final photo = await capturePhotoInApp(
      context,
      title: 'Take Supporting Feedback Photo',
    );

    if (photo == null || !mounted) {
      return;
    }

    _setEvidence(photo);
  }

  void _setEvidence(PlatformFile file) {
    if (file.path == null || file.path!.trim().isEmpty) {
      _show('The selected image could not be accessed.');
      return;
    }

    const allowedExtensions = <String>['jpg', 'jpeg', 'png', 'webp'];
    final extension = file.extension?.trim().toLowerCase() ?? '';

    if (!allowedExtensions.contains(extension)) {
      _show('Evidence must be JPG, JPEG, PNG, or WEBP.');
      return;
    }

    const maxBytes = 10 * 1024 * 1024;

    if (file.size > maxBytes) {
      _show('Evidence must not exceed 10MB.');
      return;
    }

    setState(() {
      _evidence = file;
    });
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final response = await widget.service.create(
        feedbackCategory: _feedbackCategory,
        feedbackType: _feedbackType,
        feedbackSubject: _subjectController.text,
        serviceRating: _serviceRating,
        complainantName: _nameController.text,
        contactNumber: _nullable(_contactController.text),
        complaintAddress: _nullable(_addressController.text),
        complaintDescription: _descriptionController.text,
        evidencePath: _evidence?.path,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        response['message']?.toString() ?? 'Feedback submitted successfully.',
      );
    } catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _show(exception.toString().replaceFirst('AuthException: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(title: const Text('Send Resident Feedback')),
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
                    'Send Resident Feedback',
                    style: TextStyle(
                      color: palette.textMain,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Share feedback about TabangNow, barangay services, staff response and actions, community concerns, or suggestions.',
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
                    controller: _nameController,
                    maxLength: 255,
                    decoration: const InputDecoration(
                      labelText: 'Resident Name *',
                      hintText: 'Enter resident full name',
                    ),
                    validator: (value) =>
                        _required(value, 'Resident Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactController,
                    maxLength: 30,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact Number',
                      hintText: 'Optional',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';

                      if (text.isEmpty) {
                        return null;
                      }

                      if (!RegExp(r'^[0-9+()\-\.\s]*$').hasMatch(text)) {
                        return 'Use only valid phone-number characters.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _feedbackCategory,
                    decoration: const InputDecoration(
                      labelText: 'What is this feedback about? *',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'system_experience',
                        child: Text('TabangNow System Experience'),
                      ),
                      DropdownMenuItem(
                        value: 'staff_response',
                        child: Text('Staff Response & Action'),
                      ),
                      DropdownMenuItem(
                        value: 'barangay_service',
                        child: Text('Barangay Service'),
                      ),
                      DropdownMenuItem(
                        value: 'community_concern',
                        child: Text('Community Concern'),
                      ),
                      DropdownMenuItem(
                        value: 'suggestion',
                        child: Text('Suggestion / Improvement'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _feedbackCategory = value;
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _feedbackType,
                    decoration: const InputDecoration(
                      labelText: 'Feedback Type *',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'concern',
                        child: Text('Concern'),
                      ),
                      DropdownMenuItem(
                        value: 'complaint',
                        child: Text('Complaint'),
                      ),
                      DropdownMenuItem(
                        value: 'suggestion',
                        child: Text('Suggestion'),
                      ),
                      DropdownMenuItem(
                        value: 'compliment',
                        child: Text('Compliment'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _feedbackType = value;
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subjectController,
                    maxLength: 255,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Subject *',
                      hintText: 'Short summary of your feedback',
                    ),
                    validator: (value) => _required(value, 'Subject'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: _serviceRating,
                    decoration: const InputDecoration(
                      labelText: 'Service / Experience Rating',
                      helperText: 'Optional. Choose a rating when relevant.',
                    ),
                    items: const <DropdownMenuItem<int?>>[
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Not applicable / Prefer not to rate'),
                      ),
                      DropdownMenuItem<int?>(value: 5, child: Text('5 / 5')),
                      DropdownMenuItem<int?>(value: 4, child: Text('4 / 5')),
                      DropdownMenuItem<int?>(value: 3, child: Text('3 / 5')),
                      DropdownMenuItem<int?>(value: 2, child: Text('2 / 5')),
                      DropdownMenuItem<int?>(value: 1, child: Text('1 / 5')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _serviceRating = value;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    maxLength: 500,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Location / Service Area',
                      hintText:
                          'Optional. Add a location, office, service area, or place if relevant.',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLength: 3000,
                    minLines: 6,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Feedback Details *',
                      hintText:
                          'Describe what happened, what worked well or poorly, how staff responded, what action was taken, or what you suggest should improve.',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) =>
                        _required(value, 'Feedback Details'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Supporting Picture',
                      style: TextStyle(
                        color: palette.textMain,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _takeEvidencePhoto,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(
                              _evidence == null
                                  ? 'Take Supporting Photo'
                                  : 'Retake Supporting Photo',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _pickEvidence,
                            icon: const Icon(Icons.image_outlined),
                            label: Text(
                              _evidence == null
                                  ? 'Choose Existing Picture'
                                  : 'Choose Different Picture',
                            ),
                          ),
                        ),
                        if (_evidence != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            _evidence!.name,
                            style: TextStyle(
                              color: palette.textSoft,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${(_evidence!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                            style: TextStyle(
                              color: palette.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 7),
                        Text(
                          'Accepted: JPG, JPEG, PNG, WEBP. Maximum secure-upload size: 10MB.',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
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
                          onPressed: _saving ? null : _submit,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Send Feedback'),
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

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }

    return null;
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

String? _nullable(String value) {
  final text = value.trim();

  return text.isEmpty ? null : text;
}
