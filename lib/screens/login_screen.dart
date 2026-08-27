import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/sos_flip_coin_button.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _hidePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _authService.login(
        email: _emailController.text,
        password: _passwordController.text,
        deviceName: 'TabangNow Android',
        remember: _rememberMe,
      );

      final rawUser = response['user'];

      if (rawUser is! Map) {
        throw const AuthException(
          'The server returned invalid user information.',
        );
      }

      final user = Map<String, dynamic>.from(rawUser);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to connect to TabangNow. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openForgotPassword() async {
    if (_isLoading) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordScreen(authService: _authService),
      ),
    );
  }

  Future<void> _openRegistration() async {
    if (_isLoading) {
      return;
    }

    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const RegisterScreen()),
    );

    if (!mounted || message == null || message.trim().isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _TabangNowHeader(),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Text(
                              'Log in to your account',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Use the same account you use on the '
                              'TabangNow website.',
                              style: TextStyle(
                                height: 1.4,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 28),
                            TextFormField(
                              controller: _emailController,
                              enabled: !_isLoading,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const <String>[
                                AutofillHints.email,
                              ],
                              style: const TextStyle(color: Color(0xFF0F172A)),
                              decoration: const InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                labelText: 'Email address',
                                hintText: 'email@example.com',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';

                                if (email.isEmpty) {
                                  return 'Enter your email address.';
                                }

                                if (!email.contains('@')) {
                                  return 'Enter a valid email address.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !_isLoading,
                              obscureText: _hidePassword,
                              enableSuggestions: false,
                              autocorrect: false,
                              textInputAction: TextInputAction.done,
                              autofillHints: const <String>[
                                AutofillHints.password,
                              ],
                              onFieldSubmitted: (_) {
                                if (!_isLoading) {
                                  _login();
                                }
                              },
                              style: const TextStyle(color: Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  tooltip: _hidePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            _hidePassword = !_hidePassword;
                                          });
                                        },
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your password.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Checkbox(
                                    value: _rememberMe,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: _isLoading
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _rememberMe = value ?? false;
                                            });
                                          },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Remember me',
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : _openForgotPassword,
                                child: const Text('Forgot your password?'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Log in',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Flexible(
                                  child: Text(
                                    "Don't have an account?",
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _openRegistration,
                                  child: const Text(
                                    'Sign up',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabangNowHeader extends StatelessWidget {
  const _TabangNowHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        SosFlipCoinButton(size: 104),
        SizedBox(height: 18),
        Text(
          'TabangNow',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'DAO, CAPIZ',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class AuthenticatedScreen extends StatefulWidget {
  const AuthenticatedScreen({
    required this.user,
    required this.authService,
    super.key,
  });

  final Map<String, dynamic> user;
  final AuthService authService;

  @override
  State<AuthenticatedScreen> createState() => _AuthenticatedScreenState();
}

class _AuthenticatedScreenState extends State<AuthenticatedScreen> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await widget.authService.logout();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['name']?.toString() ?? 'TabangNow User';
    final email = widget.user['email']?.toString() ?? '';
    final role = widget.user['role']?.toString() ?? 'user';

    return Scaffold(
      appBar: AppBar(title: const Text('TabangNow')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_outline,
                    size: 72,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Connected to TabangNow',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: <Widget>[
                          _UserDetail(label: 'Name', value: name),
                          const Divider(),
                          _UserDetail(label: 'Email', value: email),
                          const Divider(),
                          _UserDetail(label: 'Role', value: role),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isLoggingOut ? null : _logout,
                      child: _isLoggingOut
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Log out'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserDetail extends StatelessWidget {
  const _UserDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
