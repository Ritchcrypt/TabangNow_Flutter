import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/mobile_update_gate.dart';
import '../widgets/public_auth_branding_header.dart';
import 'auth_gate.dart';

/// Opened by a verified Android HTTPS App Link. The user never pastes a token.
/// The same Laravel broker validates the token used on the website.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    required this.token,
    required this.email,
    required this.authService,
    super.key,
  });

  final String token;
  final String email;
  final AuthService authService;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  bool _showConfirmation = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.completePasswordReset(
        token: widget.token,
        email: widget.email,
        password: _password.text,
        passwordConfirmation: _confirmation.text,
      );
      // Resetting a password invalidates all existing mobile sessions.
      await widget.authService.clearToken();
      _password.clear();
      _confirmation.clear();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Password updated'),
          content: const Text('You can now log in with your new password.'),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => const MobileUpdateGate(child: AuthGate()),
        ),
        (_) => false,
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to connect to TabangNow. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final theme = baseTheme.copyWith(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: baseTheme.colorScheme.primary,
        brightness: Brightness.light,
      ).copyWith(surface: Colors.white),
      scaffoldBackgroundColor: Colors.white,
    );
    return Theme(
      data: theme,
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Reset password'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const PublicAuthBrandingHeader(logoSize: 104),
                      const SizedBox(height: 20),
                      const Text('Set your new password',
                          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text('For ${widget.email}',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: !_showPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _showPassword ? 'Hide password' : 'Show password',
                            onPressed: _busy ? null : () => setState(() => _showPassword = !_showPassword),
                            icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter a new password.';
                          if (v.length < 8) return 'Use at least 8 characters.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmation,
                        enabled: !_busy,
                        obscureText: !_showConfirmation,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _showConfirmation ? 'Hide confirmation' : 'Show confirmation',
                            onPressed: _busy ? null : () => setState(() => _showConfirmation = !_showConfirmation),
                            icon: Icon(_showConfirmation ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          ),
                        ),
                        validator: (v) => v != _password.text ? 'Passwords do not match.' : null,
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 14),
                        Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Reset password'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
