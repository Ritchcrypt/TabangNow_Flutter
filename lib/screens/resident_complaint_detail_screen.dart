import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/tabangnow_theme.dart';
import '../services/resident_complaint_service.dart';
import 'photo_capture_screen.dart';

class ResidentComplaintDetailScreen extends StatefulWidget {
  const ResidentComplaintDetailScreen({
    super.key,
    required this.service,
    required this.complaintId,
    required this.user,
  });

  final ResidentComplaintService service;
  final int complaintId;
  final Map<String, dynamic> user;

  @override
  State<ResidentComplaintDetailScreen> createState() =>
      _ResidentComplaintDetailScreenState();
}

class _ResidentComplaintDetailScreenState
    extends State<ResidentComplaintDetailScreen> {
  final _proofNoteController = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _error;

  Map<String, dynamic> _complaint = <String, dynamic>{};

  Map<String, dynamic> _permissions = <String, dynamic>{};

  List<Map<String, dynamic>> _statuses = <Map<String, dynamic>>[];

  String? _selectedStatus;
  PlatformFile? _proofPicture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _proofNoteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await widget.service.show(widget.complaintId);

      if (!mounted) {
        return;
      }

      final complaint = _map(response['data']);

      final options = _map(response['options']);

      setState(() {
        _complaint = complaint;
        _permissions = _map(response['permissions']);

        _statuses = _mapList(options['statuses']);

        _selectedStatus = complaint['status']?.toString();

        _loading = false;
      });
    } catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = exception.toString().replaceFirst('AuthException: ', '');
      });
    }
  }

  bool _can(String key) => _permissions[key] == true;

  Future<void> _saveStatus() async {
    final status = _selectedStatus?.trim();

    if (_busy || status == null || status.isEmpty) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final response = await widget.service.updateStatus(
        complaintId: widget.complaintId,
        status: status,
      );

      if (!mounted) {
        return;
      }

      _show(
        response['message']?.toString() ??
            'Complaint status updated successfully.',
      );

      await _load();
    } catch (exception) {
      if (mounted) {
        _show(exception.toString().replaceFirst('AuthException: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _pickProof() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
    );

    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    _setProofPicture(result.files.single);
  }

  Future<void> _takeProofPhoto() async {
    final photo = await capturePhotoInApp(
      context,
      title: 'Take Action Proof Photo',
    );

    if (photo == null || !mounted) {
      return;
    }

    _setProofPicture(photo);
  }

  void _setProofPicture(PlatformFile file) {
    if (file.path == null || file.path!.trim().isEmpty) {
      _show('The selected proof image could not be accessed.');
      return;
    }

    const allowedExtensions = <String>['jpg', 'jpeg', 'png', 'webp'];
    final extension = file.extension?.trim().toLowerCase() ?? '';

    if (!allowedExtensions.contains(extension)) {
      _show('Proof must be JPG, JPEG, PNG, or WEBP.');
      return;
    }

    const maxBytes = 10 * 1024 * 1024;

    if (file.size > maxBytes) {
      _show('Proof picture must not exceed 10MB.');
      return;
    }

    setState(() {
      _proofPicture = file;
    });
  }

  Future<void> _uploadProof() async {
    final proof = _proofPicture;

    if (_busy || proof == null || proof.path == null) {
      _show('Please attach a proof picture.');
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final response = await widget.service.uploadProof(
        complaintId: widget.complaintId,
        proofPicturePath: proof.path!,
        proofNote: _nullable(_proofNoteController.text),
      );

      if (!mounted) {
        return;
      }

      _proofNoteController.clear();

      setState(() {
        _proofPicture = null;
      });

      _show(
        response['message']?.toString() ??
            'Proof picture sent to resident successfully.',
      );

      await _load();
    } catch (exception) {
      if (mounted) {
        _show(exception.toString().replaceFirst('AuthException: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _deleteComplaint() async {
    if (_busy || !_can('can_delete')) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Complaint'),
        content: const Text(
          'This removes the complaint, resident evidence, staff action proof pictures, and related notifications. This cannot be undone.',
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
            child: const Text('Delete Complaint'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final response = await widget.service.delete(widget.complaintId);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        response['message']?.toString() ?? 'Complaint deleted successfully.',
      );
    } catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
      });

      _show(exception.toString().replaceFirst('AuthException: ', ''));
    }
  }

  Future<void> _openImage({
    required String title,
    required Future<Uint8List> bytes,
  }) async {
    try {
      final data = await bytes;

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _PrivateImageScreen(title: title, bytes: data),
        ),
      );
    } catch (exception) {
      if (mounted) {
        _show(exception.toString().replaceFirst('AuthException: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(title: const Text('Complaint Details')),
      body: Column(
        children: <Widget>[
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const SizedBox(height: 100),
          const Icon(Icons.error_outline_rounded, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Try Again')),
        ],
      );
    }

    final palette = TabangNowTheme.of(context);

    final proofs = _mapList(_complaint['proofs']);

    final hasEvidence = _complaint['has_evidence'] == true;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: <Widget>[
        _Surface(
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
                          'Complaint Details',
                          style: TextStyle(
                            color: palette.textMain,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Resident complaint details, submitted evidence, and action proof.',
                          style: TextStyle(color: palette.textMuted),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(
                    status: _text(_complaint['status'], 'submitted'),
                    label: _text(_complaint['status_label'], 'Submitted'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SectionTitle(title: 'Complaint Information'),
              const SizedBox(height: 16),
              _InfoLine(
                label: 'Complainant',
                value: _text(_complaint['complainant_name'], '—'),
              ),
              _InfoLine(
                label: 'Contact Number',
                value: _text(_complaint['contact_number'], 'No contact number'),
              ),
              _InfoLine(
                label: 'Submitted Date and Time',
                value: _formatDateTime(_complaint['submitted_at']),
              ),
              _InfoLine(
                label: 'Current Status',
                value: _text(_complaint['status_label'], 'Submitted'),
              ),
              const SizedBox(height: 8),
              _TextBlock(
                label: 'Address / Location',
                value: _text(_complaint['complaint_address'], '—'),
              ),
              const SizedBox(height: 12),
              _TextBlock(
                label: 'Complaint Description',
                value: _text(_complaint['complaint_description'], '—'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SectionTitle(title: 'Resident Submitted Evidence'),
                  ),
                  const _SmallBadge(label: 'Resident'),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                'Picture uploaded by the resident when the complaint was submitted.',
                style: TextStyle(color: palette.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              if (hasEvidence)
                _PrivateImageCard(
                  future: widget.service.evidenceBytes(widget.complaintId),
                  onOpen: () => _openImage(
                    title: 'Resident Submitted Evidence',
                    bytes: widget.service.evidenceBytes(widget.complaintId),
                  ),
                )
              else
                const _EmptyPanel(
                  message: 'No resident evidence picture uploaded.',
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SectionTitle(
                      title: 'Admin / Official Action Proof',
                    ),
                  ),
                  const _SmallBadge(label: 'Staff Proof'),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                'Pictures uploaded by admin or official as proof that this complaint is being handled on the ground.',
                style: TextStyle(color: palette.textMuted, fontSize: 12),
              ),
              if (_can('can_update')) ...<Widget>[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: palette.accentText.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _takeProofPhoto,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(
                            _proofPicture == null
                                ? 'Take Action Proof Photo'
                                : 'Retake Action Proof Photo',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _pickProof,
                          icon: const Icon(Icons.image_outlined),
                          label: Text(
                            _proofPicture == null
                                ? 'Choose Existing Proof Picture'
                                : 'Choose Different Proof Picture',
                          ),
                        ),
                      ),
                      if (_proofPicture != null) ...<Widget>[
                        const SizedBox(height: 7),
                        Text(
                          _proofPicture!.name,
                          style: TextStyle(
                            color: palette.textSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: _proofNoteController,
                        maxLength: 1000,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Action Note',
                          hintText:
                              'Example: Barangay official visited the area and checked the complaint.',
                          alignLabelWithHint: true,
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : _uploadProof,
                          child: const Text(
                            'Send Action Proof Picture to Resident',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (proofs.isEmpty)
                const _EmptyPanel(
                  message:
                      'No admin or official action proof picture uploaded yet.',
                )
              else
                for (var index = 0; index < proofs.length; index++) ...<Widget>[
                  _ProofCard(
                    proof: proofs[index],
                    future: widget.service.proofBytes(
                      _int(proofs[index]['id']),
                    ),
                    onOpen: () => _openImage(
                      title: 'Staff Action Proof',
                      bytes: widget.service.proofBytes(
                        _int(proofs[index]['id']),
                      ),
                    ),
                  ),
                  if (index != proofs.length - 1) const SizedBox(height: 12),
                ],
            ],
          ),
        ),
        if (_can('can_update')) ...<Widget>[
          const SizedBox(height: 14),
          _Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SectionTitle(title: 'Update Status'),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _statuses
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status['value']?.toString(),
                          child: Text(
                            status['label']?.toString() ??
                                status['value']?.toString() ??
                                '',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                        },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _saveStatus,
                    child: const Text('Save Status'),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_can('can_delete')) ...<Widget>[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.isDark
                  ? const Color(0xFF450A0A)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Delete Complaint',
                  style: TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'This will remove the complaint, evidence picture, action proof pictures, and related notifications.',
                  style: TextStyle(
                    color: palette.isDark
                        ? const Color(0xFFFECACA)
                        : const Color(0xFFB91C1C),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB91C1C),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _busy ? null : _deleteComplaint,
                    child: const Text('Delete Complaint'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PrivateImageCard extends StatelessWidget {
  const _PrivateImageCard({required this.future, required this.onOpen});

  final Future<Uint8List> future;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 190,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const _EmptyPanel(
            message: 'The private image could not be loaded.',
          );
        }

        return InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              color: palette.surfaceMuted,
              child: Image.memory(
                snapshot.data!,
                height: 240,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProofCard extends StatelessWidget {
  const _ProofCard({
    required this.proof,
    required this.future,
    required this.onOpen,
  });

  final Map<String, dynamic> proof;
  final Future<Uint8List> future;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PrivateImageCard(future: future, onOpen: onOpen),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Uploaded by ${_text(proof['uploader_name'], 'Admin / Official')}',
                  style: TextStyle(
                    color: palette.textMain,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_capitalize(_text(proof['uploader_role'], 'staff'))} Action Proof',
                  style: TextStyle(
                    color: palette.accentText,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (_text(proof['proof_note'], '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _text(proof['proof_note'], ''),
                    style: TextStyle(color: palette.textSoft, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateImageScreen extends StatelessWidget {
  const _PrivateImageScreen({required this.title, required this.bytes});

  final String title;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(title)),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: TabangNowTheme.of(context).textMain,
        fontSize: 18,
        fontWeight: FontWeight.w900,
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
    final palette = TabangNowTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: palette.textMain,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: palette.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(color: palette.textSoft, height: 1.5),
          ),
        ),
      ],
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

    final colors = _statusColors(palette, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.$2.withValues(alpha: 0.25)),
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

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: palette.textSoft,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: palette.textMuted, fontWeight: FontWeight.w700),
      ),
    );
  }
}

(Color, Color) _statusColors(TabangNowTheme palette, String status) {
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

int _int(Object? value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _text(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? fallback : text;
}

String? _nullable(String value) {
  final text = value.trim();

  return text.isEmpty ? null : text;
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }

  return '${value[0].toUpperCase()}${value.substring(1)}';
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
