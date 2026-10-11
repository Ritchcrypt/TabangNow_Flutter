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

  final _addressController = TextEditingController();

  final _descriptionController = TextEditingController();

  PlatformFile? _evidence;
  bool _saving = false;

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
      title: 'Take Complaint Evidence Photo',
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
        complainantName: _nameController.text,
        contactNumber: _nullable(_contactController.text),
        complaintAddress: _addressController.text,
        complaintDescription: _descriptionController.text,
        evidencePath: _evidence?.path,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        response['message']?.toString() ?? 'Complaint submitted successfully.',
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
      appBar: AppBar(title: const Text('Submit Complaint')),
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
                    'Submit Complaint',
                    style: TextStyle(
                      color: palette.textMain,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Report a non-emergency community concern to the barangay office.',
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
                      labelText: 'Complainant Full Name *',
                      hintText: 'Enter complainant full name',
                    ),
                    validator: (value) =>
                        _required(value, 'Complainant Full Name'),
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
                  TextFormField(
                    controller: _addressController,
                    maxLength: 500,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Address / Location of Complaint *',
                      hintText:
                          'Example: Purok 2, near covered court, Dao, Capiz',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) =>
                        _required(value, 'Address / Location'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLength: 3000,
                    minLines: 6,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Complaint Description *',
                      hintText: 'Describe the complaint clearly.',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) =>
                        _required(value, 'Complaint Description'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Evidence Picture',
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
                                  ? 'Take Evidence Photo'
                                  : 'Retake Evidence Photo',
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
                              : const Text('Submit Complaint'),
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
