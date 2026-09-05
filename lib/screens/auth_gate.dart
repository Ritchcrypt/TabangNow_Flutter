import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/sos_flip_coin_button.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _checkingSession = true;
  bool _loggingIn = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  Map<String, dynamic>? _user;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    try {
      final token = await _authService.getToken();

      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() => _checkingSession = false);
        }
        return;
      }

      final response = await _authService.me();
      final rawUser = response['user'];

      if (!mounted) {
        return;
      }

      if (rawUser is Map) {
        setState(() {
          _user = Map<String, dynamic>.from(rawUser);
          _checkingSession = false;
        });
        return;
      }

      await _authService.clearToken();
    } catch (_) {
      await _authService.clearToken();
    }

    if (mounted) {
      setState(() => _checkingSession = false);
    }
  }

  Future<void> _login() async {
    if (_loggingIn || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _loggingIn = true;
      _loginError = null;
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
          'The server did not return account information.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _user = Map<String, dynamic>.from(rawUser);
        _loggingIn = false;
      });
    } on AuthException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loggingIn = false;
        _loginError = exception.userMessage;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loggingIn = false;
        _loginError = 'Unable to connect to TabangNow.';
      });
    }
  }

  Future<void> _openForgotPassword() async {
    if (_loggingIn) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordScreen(authService: _authService),
      ),
    );
  }

  Future<void> _openRegistration() async {
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

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF64748B)),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2F6FED), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFF87171), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F7FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user != null) {
      return HomeScreen(user: _user!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: <Widget>[
                  const SosFlipCoinButton(
                    size: 148,
                    showShadow: false,
                    logoFit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'TabangNow',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 46,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'DAO, CAPIZ',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3.3,
                    ),
                  ),
                  const SizedBox(height: 52),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFD8E0EA)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Log in to your account',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 31,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Use the same account you use on the TabangNow website.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 17,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 34),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[AutofillHints.email],
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 17,
                            ),
                            decoration: _fieldDecoration(
                              hint: 'Email address',
                              icon: Icons.email_outlined,
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Enter your email address.';
                              }
                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(text)) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _loggingIn
                                  ? null
                                  : _openForgotPassword,
                              child: const Text('Forgot your password?'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const <String>[
                              AutofillHints.password,
                            ],
                            onFieldSubmitted: (_) => _login(),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 17,
                            ),
                            decoration: _fieldDecoration(
                              hint: 'Password',
                              icon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            validator: (value) => (value?.isEmpty ?? true)
                                ? 'Enter your password.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: <Widget>[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Checkbox(
                                  value: _rememberMe,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  onChanged: _loggingIn
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
                            child: const SizedBox.shrink(),
                          ),
                          if (_loginError != null) ...<Widget>[
                            const SizedBox(height: 14),
                            Text(
                              _loginError!,
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2F6FED),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: _loggingIn ? null : _login,
                              child: _loggingIn
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Log in',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Flexible(
                                child: Text(
                                  "Don't have an account?",
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: _loggingIn
                                    ? null
                                    : _openRegistration,
                                child: const Text(
                                  'Sign up',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
