import 'dart:async';

import 'package:flutter/material.dart';

import '../services/account_mfa_service.dart';
import '../services/auth_service.dart';
import '../services/native_push_service.dart';

/// First-party in-app enrollment, shared Laravel TOTP and recovery codes.
class AccountMfaScreen extends StatefulWidget {
  const AccountMfaScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<AccountMfaScreen> createState() => _AccountMfaScreenState();
}

class _AccountMfaScreenState extends State<AccountMfaScreen> {
  final _password = TextEditingController();
  final _code = TextEditingController();
  late final AccountMfaService _service;

  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;
  bool _showPassword = false;
  int _remaining = 0;
  String? _secret;
  String? _error;
  String? _message;
  List<String> _recoveryCodes = <String>[];

  @override
  void initState() {
    super.initState();
    _service = AccountMfaService(authService: widget.authService);
    _refresh();
  }

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final data = await _service.status();
      if (!mounted) return;
      setState(() {
        _enabled = data['enabled'] == true;
        _remaining = (data['recovery_codes_remaining'] as num?)?.toInt() ?? 0;
        _loading = false;
        _error = null;
      });
    } on AuthException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Unable to load MFA status.'; _loading = false; });
    }
  }

  Future<void> _perform(Future<Map<String, dynamic>> Function() action,
      {required String operation}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; _message = null; });
    try {
      final data = await action();
      // Show one-time recovery codes immediately. Push registration is optional
      // and must never delay, hide, or discard these codes.
      if (!mounted) return;
      setState(() {
        if (operation == 'begin') {
          _secret = data['secret']?.toString();
          _message = 'Add this setup key to an authenticator app, then enter its six-digit code within 10 minutes.';
        } else if (operation == 'confirm' || operation == 'recovery') {
          _secret = null;
          if (operation == 'confirm') _enabled = true;
          _recoveryCodes = (data['recovery_codes'] as List<dynamic>?)
                  ?.map((item) => item.toString()).toList() ?? <String>[];
          _remaining = _recoveryCodes.length;
          _message = 'Save these recovery codes securely. They are only displayed now.';
        } else if (operation == 'disable') {
          _enabled = false;
          _secret = null;
          _remaining = 0;
          _recoveryCodes = <String>[];
          _message = 'Two-factor authentication disabled. Other mobile sessions were signed out.';
        }
        _password.clear();
        _code.clear();
      });
      if (operation == 'confirm' || operation == 'disable') {
        unawaited(_restorePushRegistration());
      }
    } on AuthException catch (e) {
      if (mounted) setState(() { _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Unable to complete the MFA request.'; });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _restorePushRegistration() async {
    try {
      await NativePushService.instance.syncForAuthenticatedUser(widget.authService);
    } catch (_) {
      // MFA is already updated. A push registration failure must not invalidate
      // the verified session or the single-display recovery codes.
    }
  }

  Future<void> _tryClose() async {
    if (_busy) return;
    if (_recoveryCodes.isNotEmpty) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Have you saved your recovery codes?'),
          content: const Text('For security, these codes cannot be viewed again after you leave. Store them securely offline.'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('I Saved Them')),
          ],
        ),
      );
      if (leave != true || !mounted) return;
      setState(() => _recoveryCodes = <String>[]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget _passwordField() => TextField(
    controller: _password,
    enabled: !_busy,
    obscureText: !_showPassword,
    decoration: InputDecoration(
      labelText: 'Current account password',
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: _showPassword ? 'Hide password' : 'Show password',
        onPressed: () => setState(() => _showPassword = !_showPassword),
        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
      ),
    ),
  );

  Widget _codeField({bool onlyDigits = false}) => TextField(
    controller: _code,
    enabled: !_busy,
    keyboardType: onlyDigits ? TextInputType.number : TextInputType.text,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(
      labelText: onlyDigits ? 'Six-digit authenticator code' : 'Authenticator or recovery code',
      prefixIcon: const Icon(Icons.pin_outlined),
    ),
  );

  Widget _action(String label, VoidCallback? action, {bool destructive = false}) =>
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _busy ? null : action,
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C))
              : null,
          child: Text(_busy ? 'Processing...' : label),
        ),
      );

  Widget _codesPanel() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('One-time recovery codes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Keep these codes offline. Each works only once. Leaving this page removes them from view.'),
          const SizedBox(height: 12),
          ..._recoveryCodes.map((code) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SelectableText(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
          )),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() => _recoveryCodes = <String>[]),
            child: const Text('I have saved these codes'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy && _recoveryCodes.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _tryClose();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _tryClose),
          title: const Text('Account Security'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(18),
                children: <Widget>[
                  const Text('Two-Factor Authentication (MFA)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21)),
                  const SizedBox(height: 8),
                  const Text('Optional protection for your TabangNow account. Use an authenticator app on both the website and mobile app.'),
                  const SizedBox(height: 16),
                  Text('Status: ${_enabled ? 'Enabled' : 'Not enabled'}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (_enabled) Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Unused recovery codes: $_remaining'),
                  ),
                  if (_error != null) Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
                  ),
                  if (_message != null) Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(_message!),
                  ),
                  if (_recoveryCodes.isNotEmpty) _codesPanel(),
                  if (!_enabled && _secret == null) ...<Widget>[
                    const SizedBox(height: 18),
                    _passwordField(),
                    const SizedBox(height: 12),
                    _action('Enable Two-Factor Authentication', () => _perform(
                      () => _service.begin(_password.text), operation: 'begin')),
                  ],
                  if (!_enabled && _secret != null) ...<Widget>[
                    const SizedBox(height: 18),
                    const Text('In Google Authenticator, Microsoft Authenticator, or another TOTP app, choose Enter a setup key. Account: TabangNow. Type: Time based.'),
                    const SizedBox(height: 10),
                    const Text('Setup key:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SelectableText(_secret!, style: const TextStyle(fontFamily: 'monospace', fontSize: 17)),
                    const SizedBox(height: 14),
                    _codeField(onlyDigits: true),
                    const SizedBox(height: 12),
                    _action('Verify and Enable MFA', () => _perform(
                      () => _service.confirm(_code.text), operation: 'confirm')),
                    TextButton(onPressed: _busy ? null : () => setState(() {
                      _secret = null;
                      _code.clear();
                    }), child: const Text('Cancel setup')),
                  ],
                  if (_enabled) ...<Widget>[
                    const SizedBox(height: 20),
                    const Text('Generate new recovery codes', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('This replaces all previous codes. Confirm your password and a code.'),
                    const SizedBox(height: 10),
                    _passwordField(),
                    const SizedBox(height: 10),
                    _codeField(),
                    const SizedBox(height: 12),
                    _action('Generate New Recovery Codes', () => _perform(
                      () => _service.regenerate(password: _password.text, code: _code.text),
                      operation: 'recovery')),
                    const Divider(height: 40),
                    const Text('Disable Two-Factor Authentication', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('Disabling MFA lowers account security. Use your account password and an authenticator or recovery code above.'),
                    const SizedBox(height: 12),
                    _action('Disable MFA', () async {
                      final agreed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Disable MFA?'),
                          content: const Text('Your account will no longer require a second factor when signing in.'),
                          actions: <Widget>[
                            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Disable')),
                          ],
                        ),
                      );
                      if (agreed != true || !mounted) return;
                      await _perform(() => _service.disable(password: _password.text, code: _code.text), operation: 'disable');
                    }, destructive: true),
                  ],
                  const SizedBox(height: 20),
                  const Text('If both your authenticator and recovery codes are lost, contact an authorized administrator for identity verification. Never send your password or codes to anyone.',
                    style: TextStyle(fontSize: 12)),
                ],
              ),
      ),
    );
  }
}
