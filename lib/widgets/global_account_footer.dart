import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';

class GlobalAccountFooter extends StatefulWidget {
  const GlobalAccountFooter({
    super.key,
    required this.user,
    required this.authService,
    required this.roleLabel,
    required this.initials,
    required this.onProfile,
    required this.onSessionAction,
    this.sessionActionLabel = 'Restart Dev Session',
    this.sessionActionBusy = false,
  });

  final Map<String, dynamic> user;
  final AuthService authService;
  final String roleLabel;
  final String initials;
  final Future<void> Function() onProfile;
  final Future<void> Function() onSessionAction;
  final String sessionActionLabel;
  final bool sessionActionBusy;

  @override
  State<GlobalAccountFooter> createState() => _GlobalAccountFooterState();
}

class _GlobalAccountFooterState extends State<GlobalAccountFooter> {
  late ProfileService _profileService;

  Uint8List? _photoBytes;
  bool _photoLoaded = false;

  int get _userId => int.tryParse(widget.user['id']?.toString() ?? '') ?? 0;

  String get _name {
    final value = widget.user['name']?.toString().trim();

    return value == null || value.isEmpty ? 'User' : value;
  }

  @override
  void initState() {
    super.initState();

    _profileService = ProfileService(authService: widget.authService);

    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant GlobalAccountFooter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.authService != widget.authService) {
      _profileService = ProfileService(authService: widget.authService);
    }

    final oldId = int.tryParse(oldWidget.user['id']?.toString() ?? '') ?? 0;

    final oldPhotoVersion = oldWidget.user['profile_photo_version']?.toString();
    final newPhotoVersion = widget.user['profile_photo_version']?.toString();

    if (oldId != _userId ||
        oldWidget.user['name'] != widget.user['name'] ||
        oldPhotoVersion != newPhotoVersion) {
      _photoBytes = null;
      _photoLoaded = false;
      _loadPhoto();
    }
  }

  Future<void> _loadPhoto() async {
    if (_photoLoaded || _userId <= 0) {
      return;
    }

    _photoLoaded = true;

    try {
      final bytes = await _profileService.photoBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _photoBytes = bytes;
      });
    } catch (_) {
    }
  }

  Future<void> _showMenu() async {
    final action = await showModalBottomSheet<_AccountMenuAction>(
      context: context,
      backgroundColor: const Color(0xFF172554),
      barrierColor: Colors.black54,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF1E3A8A))),
                ),
                child: Row(
                  children: <Widget>[
                    _AccountAvatar(
                      bytes: _photoBytes,
                      initials: widget.initials,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.roleLabel,
                            style: const TextStyle(
                              color: Color(0xFFBFDBFE),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _AccountActionTile(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AccountMenuAction.profile),
              ),
              const Divider(height: 1, color: Color(0xFF1E3A8A)),
              _AccountActionTile(
                icon: Icons.restart_alt_rounded,
                label: widget.sessionActionLabel,
                disabled: widget.sessionActionBusy,
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AccountMenuAction.session),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _AccountMenuAction.profile:
        await widget.onProfile();
        break;
      case _AccountMenuAction.session:
        if (!widget.sessionActionBusy) {
          await widget.onSessionAction();
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.sessionActionBusy ? null : _showMenu,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: <Widget>[
                _AccountAvatar(
                  bytes: _photoBytes,
                  initials: widget.initials,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.roleLabel,
                        style: const TextStyle(
                          color: Color(0xFFBFDBFE),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.more_horiz_rounded,
                  color: Color(0xFFBFDBFE),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _AccountMenuAction { profile, session }

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({
    required this.bytes,
    required this.initials,
    required this.size,
  });

  final Uint8List? bytes;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final data = bytes;

    if (data != null && data.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          data,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _InitialAvatar(initials: initials, size: size),
        ),
      );
    }

    return _InitialAvatar(initials: initials, size: size);
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF2563EB),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials.isEmpty ? 'U' : initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size >= 44 ? 14 : 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AccountActionTile extends StatelessWidget {
  const _AccountActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 21,
              color: disabled
                  ? const Color(0xFF64748B)
                  : const Color(0xFFDBEAFE),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: disabled
                      ? const Color(0xFF64748B)
                      : const Color(0xFFDBEAFE),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
