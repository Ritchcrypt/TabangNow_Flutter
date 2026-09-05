import 'package:flutter/material.dart';

import '../services/registration_service.dart';
import '../widgets/public_auth_branding_header.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final RegistrationService _registrationService = RegistrationService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _submitting = true);

    try {
      final result = await _registrationService.registerResident(
        name: _nameController.text,
        email: _emailController.text,
        contactNumber: _contactController.text,
        address: _addressController.text,
        password: _passwordController.text,
        passwordConfirmation: _confirmationController.text,
      );

      if (!mounted) {
        return;
      }

      final message = result['message']?.toString().trim();
      final finalMessage = message == null || message.isEmpty
          ? 'Your resident account was created successfully and is awaiting administrator approval.'
          : message;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF059669),
            size: 42,
          ),
          title: const Text('Registration submitted'),
          content: Text(finalMessage),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Back to login'),
            ),
          ],
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(finalMessage);
    } on RegistrationException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(exception.userMessage)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to submit registration. Please retry.'),
          ),
        );
    }
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: theme.colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Create account'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: <Widget>[
                  const PublicAuthBrandingHeader(logoSize: 78),
                  const SizedBox(height: 26),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Resident Registration',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Create a resident account',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Public registration creates a Resident account. Administrator approval is required before you can log in.',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            decoration: _fieldDecoration(
                              hint: 'Full name',
                              icon: Icons.person_outline_rounded,
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? 'Enter your full name.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const <String>[AutofillHints.email],
                            style: TextStyle(color: theme.colorScheme.onSurface),
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
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _contactController,
                            keyboardType: TextInputType.phone,
                            autofillHints: const <String>[
                              AutofillHints.telephoneNumber,
                            ],
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            decoration: _fieldDecoration(
                              hint: '09XXXXXXXXX',
                              icon: Icons.phone_outlined,
                            ),
                            validator: (value) {
                              var number = (value ?? '').trim().replaceAll(
                                RegExp(r'[\s\-\(\)]'),
                                '',
                              );
                              if (number.startsWith('+63')) {
                                number = '0${number.substring(3)}';
                              }
                              return RegExp(r'^09\d{9}$').hasMatch(number)
                                  ? null
                                  : 'Enter a valid Philippine mobile number.';
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _addressController,
                            minLines: 2,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            decoration: _fieldDecoration(
                              hint: 'Complete address',
                              icon: Icons.location_on_outlined,
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? 'Enter your complete address.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const <String>[
                              AutofillHints.newPassword,
                            ],
                            style: TextStyle(color: theme.colorScheme.onSurface),
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
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final text = value ?? '';
                              if (text.isEmpty) {
                                return 'Enter a password.';
                              }
                              if (text.length < 8) {
                                return 'Use at least 8 characters.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmationController,
                            obscureText: _obscureConfirmation,
                            autofillHints: const <String>[
                              AutofillHints.newPassword,
                            ],
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            decoration: _fieldDecoration(
                              hint: 'Confirm password',
                              icon: Icons.lock_reset_rounded,
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscureConfirmation =
                                      !_obscureConfirmation,
                                ),
                                icon: Icon(
                                  _obscureConfirmation
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                value == _passwordController.text
                                ? null
                                : 'Passwords do not match.',
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 17,
                                ),
                              ),
                              onPressed: _submitting ? null : _submit,
                              child: _submitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Create resident account',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text(
                                'Already have an account? Log in',
                              ),
                            ),
                          ),
                        ],
                      ),
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
