import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/tabangnow_theme.dart';
import '../services/auth_service.dart';
import '../services/global_image_crop_service.dart';
import '../services/profile_service.dart';

class CurrentAccountProfileScreen extends StatefulWidget {
  const CurrentAccountProfileScreen({
    super.key,
    required this.authService,
    required this.fallbackUser,
  });

  final AuthService authService;
  final Map<String, dynamic> fallbackUser;

  @override
  State<CurrentAccountProfileScreen> createState() =>
      _CurrentAccountProfileScreenState();
}

class _CurrentAccountProfileScreenState
    extends State<CurrentAccountProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();

  final _otherSessionsPasswordController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _deletePasswordController = TextEditingController();

  late final ProfileService _service;

  bool _loading = true;
  bool _savingProfile = false;
  bool _sessionBusy = false;
  bool _passwordBusy = false;
  bool _deleteBusy = false;
  bool _changed = false;
  bool _showPasswordPanel = false;
  bool _showDeletePanel = false;

  bool _showOtherSessionsPassword = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _showDeletePassword = false;

  String? _error;
  Map<String, dynamic> _user = <String, dynamic>{};
  Map<String, dynamic> _permissions = <String, dynamic>{};
  Map<String, dynamic> _passwordPolicy = <String, dynamic>{};
  Uint8List? _photoBytes;
  PlatformFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;

  @override
  void initState() {
    super.initState();
    _service = ProfileService(authService: widget.authService);
    _user = Map<String, dynamic>.from(widget.fallbackUser);
    _applyUser(_user);
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _otherSessionsPasswordController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _deletePasswordController.dispose();
    super.dispose();
  }

  void _applyUser(Map<String, dynamic> user) {
    _nameController.text = _text(user['name'], '');
    _emailController.text = _text(user['email'], '');
    _contactController.text = _text(user['contact_number'], '');
    _addressController.text = _text(user['address'], '');
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await _service.show();
      final rawUser = response['data'];
      final user = rawUser is Map
          ? Map<String, dynamic>.from(rawUser)
          : Map<String, dynamic>.from(_user);
      final permissions = _map(response['permissions']);
      final policy = _map(response['password_policy']);

      Uint8List? photo;
      if (user['has_profile_photo'] == true) {
        try {
          photo = await _service.photoBytes();
        } catch (_) {
          photo = null;
        }
      }

      if (!mounted) return;

      _applyUser(user);
      setState(() {
        _user = user;
        _permissions = permissions;
        _passwordPolicy = policy;
        _photoBytes = photo;
        _selectedPhoto = null;
        _selectedPhotoBytes = null;
        _loading = false;
        _error = null;
      });
    } on AuthException catch (exception) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = exception.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load your profile.';
      });
    }
  }

  Future<void> _pickPhoto() async {
    if (_savingProfile) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    try {
      final cropped = await GlobalImageCropService.crop(
        file: result.files.single,
        mode: GlobalImageCropMode.square,
        title: 'Adjust Profile Photo',
      );

      if (cropped == null) return;

      if (cropped.size > 5 * 1024 * 1024) {
        _showMessage('Profile photo must not exceed 5 MB.');
        return;
      }

      final path = cropped.path?.trim() ?? '';
      if (path.isEmpty) {
        throw const GlobalImageCropException(
          'The cropped profile photo could not be opened.',
        );
      }

      final bytes = await File(path).readAsBytes();
      if (!mounted) return;

      setState(() {
        _selectedPhoto = cropped;
        _selectedPhotoBytes = bytes;
      });
    } on GlobalImageCropException catch (exception) {
      _showMessage(exception.message);
    } catch (_) {
      _showMessage('The selected profile photo could not be prepared.');
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (_savingProfile ||
        !(_profileFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _savingProfile = true;
      _error = null;
    });

    try {
      final response = await _service.update(
        name: _nameController.text,
        email: _emailController.text,
        contactNumber: _contactController.text,
        address: _addressController.text,
        profilePhotoPath: _selectedPhoto?.path,
      );

      final rawUser = response['data'];
      final user = rawUser is Map
          ? Map<String, dynamic>.from(rawUser)
          : Map<String, dynamic>.from(_user);

      Uint8List? photo = _selectedPhotoBytes;
      if (photo == null && user['has_profile_photo'] == true) {
        try {
          photo = await _service.photoBytes();
        } catch (_) {
          photo = _photoBytes;
        }
      }

      if (!mounted) return;
      _applyUser(user);

      setState(() {
        _user = user;
        _photoBytes = photo;
        _selectedPhoto = null;
        _selectedPhotoBytes = null;
        _savingProfile = false;
        _changed = true;
      });

      _showMessage(
        response['email_verification_required'] == true
            ? 'Profile updated. Your changed email address needs verification.'
            : 'Profile updated successfully.',
      );
    } on AuthException catch (exception) {
      if (!mounted) return;
      setState(() {
        _savingProfile = false;
        _error = exception.message;
      });
      _showMessage(exception.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingProfile = false;
        _error = 'Unable to update your profile.';
      });
      _showMessage('Unable to update your profile.');
    }
  }

  Future<void> _signOutOtherDevices() async {
    final password = _otherSessionsPasswordController.text;
    if (_sessionBusy || password.isEmpty) {
      if (password.isEmpty) _showMessage('Enter your current password.');
      return;
    }

    final confirmed = await _confirm(
      title: 'Sign Out Other Devices',
      message:
          'Sign this account out from every other browser and device? This phone will remain signed in.',
      confirmLabel: 'Sign Out Others',
    );
    if (!confirmed || !mounted) return;

    setState(() => _sessionBusy = true);

    try {
      final response = await _service.signOutOtherDevices(password: password);
      _otherSessionsPasswordController.clear();
      _showMessage(
        _text(
          response['message'],
          'Other browser and device sessions were signed out successfully.',
        ),
      );
    } on AuthException catch (exception) {
      _showMessage(exception.message);
    } catch (_) {
      _showMessage('Unable to sign out other devices.');
    } finally {
      if (mounted) setState(() => _sessionBusy = false);
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPasswordController.text;
    final password = _newPasswordController.text;
    final confirmation = _confirmPasswordController.text;

    if (_passwordBusy) return;

    final localError = _validateNewPassword(
      current: current,
      password: password,
      confirmation: confirmation,
    );

    if (localError != null) {
      _showMessage(localError);
      return;
    }

    setState(() => _passwordBusy = true);

    try {
      final response = await _service.changePassword(
        currentPassword: current,
        newPassword: password,
        confirmation: confirmation,
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (mounted) {
        setState(() => _showPasswordPanel = false);
      }

      _showMessage(
        _text(response['message'], 'Password updated successfully.'),
      );
    } on AuthException catch (exception) {
      _showMessage(exception.message);
    } catch (_) {
      _showMessage('Unable to update your password.');
    } finally {
      if (mounted) setState(() => _passwordBusy = false);
    }
  }

  Future<void> _deleteOwnAccount() async {
    final password = _deletePasswordController.text;
    if (_deleteBusy || password.isEmpty) {
      if (password.isEmpty) _showMessage('Enter your current password.');
      return;
    }

    final confirmed = await _confirm(
      title: 'Permanent Delete Account',
      message:
          'Permanently delete this account? This action cannot be undone. Your current session and all other sessions will be revoked.',
      confirmLabel: 'Delete Permanently',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final finalConfirmation = await _confirm(
      title: 'Final Confirmation',
      message:
          'This is irreversible. Delete your TabangNow account permanently?',
      confirmLabel: 'Yes, Delete My Account',
      destructive: true,
    );
    if (!finalConfirmation || !mounted) return;

    setState(() => _deleteBusy = true);

    try {
      final response = await _service.deleteOwnAccount(password: password);
      if (!mounted) return;

      Navigator.of(context).pop(<String, dynamic>{
        'account_deleted': true,
        'message': _text(
          response['message'],
          'Your account was permanently deleted.',
        ),
      });
    } on AuthException catch (exception) {
      _showMessage(exception.message);
      if (mounted) setState(() => _deleteBusy = false);
    } catch (_) {
      _showMessage('Unable to permanently delete the account.');
      if (mounted) setState(() => _deleteBusy = false);
    }
  }

  String? _validateNewPassword({
    required String current,
    required String password,
    required String confirmation,
  }) {
    final minimum = _int(_passwordPolicy['minimum_length'], fallback: 12);

    if (current.isEmpty) return 'Enter your current password.';
    if (password.length < minimum) {
      return 'New password must contain at least $minimum characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password)) {
      return 'New password must contain uppercase and lowercase letters.';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'New password must contain a number.';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'New password must contain a symbol.';
    }
    if (password == current) {
      return 'New password must be different from your current password.';
    }
    if (password != confirmation) {
      return 'New password confirmation does not match.';
    }
    return null;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB91C1C),
                        foregroundColor: Colors.white,
                      )
                    : null,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _close() {
    Navigator.of(context).pop<Map<String, dynamic>?>(
      _changed ? Map<String, dynamic>.from(_user) : null,
    );
  }

  Uint8List? get _previewPhoto => _selectedPhotoBytes ?? _photoBytes;
  bool get _canSignOutOtherDevices =>
      _permissions['can_sign_out_other_devices'] == true;
  bool get _canChangePassword => _permissions['can_change_password'] == true;
  bool get _canSelfDelete => _permissions['can_self_delete'] == true;
  bool get _busy =>
      _savingProfile || _sessionBusy || _passwordBusy || _deleteBusy;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: palette.pageBackground,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _busy ? null : _close,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('My Profile'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _nameController.text.trim().isEmpty
            ? _loadError()
            : RefreshIndicator(onRefresh: _load, child: _body()),
      ),
    );
  }

  Widget _loadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(_error ?? 'Unable to load your profile.'),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final palette = TabangNowTheme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: <Widget>[
        _section(
          child: Form(
            key: _profileFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Account Information',
                  style: TextStyle(
                    color: palette.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      _ProfileAvatar(
                        bytes: _previewPhoto,
                        name: _text(_user['name'], 'User'),
                      ),
                      Positioned(
                        right: -5,
                        bottom: -5,
                        child: Material(
                          color: Theme.of(context).colorScheme.primary,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Change profile picture',
                            onPressed: _savingProfile ? null : _pickPhoto,
                            color: Colors.white,
                            icon: const Icon(
                              Icons.camera_alt_rounded,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'JPG, PNG or WEBP • maximum 5 MB • square crop',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.textMuted, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  enabled: !_savingProfile,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Full name is required.';
                    if (text.length > 255) return 'Maximum 255 characters.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  enabled: !_savingProfile,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Email is required.';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                      return 'Enter a valid email address.';
                    }
                    if (text.length > 255) return 'Maximum 255 characters.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contactController,
                  enabled: !_savingProfile,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number',
                    hintText: 'Example: 09123456789',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length > 30) return 'Maximum 30 characters.';
                    if (text.isNotEmpty &&
                        !RegExp(r'^[0-9+()\-\s]*$').hasMatch(text)) {
                      return 'Use only valid phone-number characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  enabled: !_savingProfile,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => (value ?? '').length > 1000
                      ? 'Maximum 1000 characters.'
                      : null,
                ),
                const SizedBox(height: 16),
                _ReadOnlyLine(
                  label: 'Role',
                  value: _text(
                    _user['role_label'],
                    _pretty(_text(_user['role'], 'User')),
                  ),
                ),
                _ReadOnlyLine(
                  label: 'Status',
                  value: _text(_user['status_label'], 'Active'),
                  isLast: true,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _savingProfile ? null : _saveProfile,
                    icon: _savingProfile
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_savingProfile ? 'Saving...' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_canSignOutOtherDevices) ...<Widget>[
          const SizedBox(height: 14),
          _section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Session Security',
                  style: TextStyle(
                    color: palette.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign out this account from every other browser or device. This phone will remain signed in.',
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _otherSessionsPasswordController,
                  obscureText: !_showOtherSessionsPassword,
                  enabled: !_sessionBusy,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: _visibilityButton(
                      shown: _showOtherSessionsPassword,
                      onPressed: () => setState(() {
                        _showOtherSessionsPassword =
                            !_showOtherSessionsPassword;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _sessionBusy ? null : _signOutOtherDevices,
                    icon: const Icon(Icons.devices_other_rounded),
                    label: Text(
                      _sessionBusy
                          ? 'Signing Out...'
                          : 'Sign Out Other Devices',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_canChangePassword || _canSelfDelete) ...<Widget>[
          const SizedBox(height: 14),
          _section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Account Security',
                  style: TextStyle(
                    color: palette.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    if (_canChangePassword)
                      OutlinedButton.icon(
                        onPressed: _passwordBusy
                            ? null
                            : () => setState(() {
                                _showPasswordPanel = !_showPasswordPanel;
                              }),
                        icon: const Icon(Icons.password_rounded),
                        label: const Text('Reset Password'),
                      ),
                    if (_canSelfDelete)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB91C1C),
                        ),
                        onPressed: _deleteBusy
                            ? null
                            : () => setState(() {
                                _showDeletePanel = !_showDeletePanel;
                              }),
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: const Text('Permanent Delete'),
                      ),
                  ],
                ),
                if (_showPasswordPanel && _canChangePassword) ...<Widget>[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFDE68A)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Reset Password',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Minimum 12 characters with uppercase, lowercase, a number, and a symbol.',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _passwordField(
                          controller: _currentPasswordController,
                          label: 'Current Password',
                          shown: _showCurrentPassword,
                          onToggle: () => setState(() {
                            _showCurrentPassword = !_showCurrentPassword;
                          }),
                        ),
                        const SizedBox(height: 12),
                        _passwordField(
                          controller: _newPasswordController,
                          label: 'New Password',
                          shown: _showNewPassword,
                          onToggle: () => setState(() {
                            _showNewPassword = !_showNewPassword;
                          }),
                        ),
                        const SizedBox(height: 12),
                        _passwordField(
                          controller: _confirmPasswordController,
                          label: 'Confirm New Password',
                          shown: _showConfirmPassword,
                          onToggle: () => setState(() {
                            _showConfirmPassword = !_showConfirmPassword;
                          }),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _passwordBusy ? null : _changePassword,
                            child: Text(
                              _passwordBusy ? 'Saving...' : 'Save New Password',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_showDeletePanel && _canSelfDelete) ...<Widget>[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFECACA)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Permanent Delete Account',
                          style: TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'This permanently deletes your account. This action cannot be undone.',
                          style: TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _passwordField(
                          controller: _deletePasswordController,
                          label: 'Confirm Password',
                          shown: _showDeletePassword,
                          onToggle: () => setState(() {
                            _showDeletePassword = !_showDeletePassword;
                          }),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFB91C1C),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _deleteBusy ? null : _deleteOwnAccount,
                            icon: const Icon(Icons.delete_forever_rounded),
                            label: Text(
                              _deleteBusy
                                  ? 'Deleting...'
                                  : 'Delete My Account Permanently',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(
              color: Color(0xFFB91C1C),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _section({required Widget child}) {
    final palette = TabangNowTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool shown,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !shown,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: _visibilityButton(shown: shown, onPressed: onToggle),
      ),
    );
  }

  Widget _visibilityButton({
    required bool shown,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: shown ? 'Hide password' : 'Show password',
      onPressed: onPressed,
      icon: Icon(
        shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.bytes, required this.name});

  final Uint8List? bytes;
  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);
    final data = bytes;

    if (data != null && data.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          data,
          width: 112,
          height: 112,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }

    return Container(
      width: 112,
      height: 112,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.accentSoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: palette.accentText,
          fontSize: 42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReadOnlyLine extends StatelessWidget {
  const _ReadOnlyLine({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = TabangNowTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.textSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _text(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _pretty(String value) {
  if (value == '—') return value;
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
