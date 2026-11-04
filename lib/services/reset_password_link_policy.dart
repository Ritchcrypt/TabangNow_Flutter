/// The reset-link origin must be the same HTTPS origin as the Laravel API.
/// Android App Links and this Dart check are complementary security checks.
class PasswordResetLink {
  const PasswordResetLink({required this.token, required this.email});

  final String token;
  final String email;
}

class PasswordResetLinkPolicy {
  PasswordResetLinkPolicy._();

  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static final RegExp _tokenPattern = RegExp(r'^[A-Za-z0-9]{16,}$');
  static final RegExp _emailPattern =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static PasswordResetLink? parse(
    String raw, {
    String? apiBaseUrl,
  }) {
    final server = Uri.tryParse(apiBaseUrl ?? _configuredApiBaseUrl);
    final incoming = Uri.tryParse(raw.trim());
    if (server == null || incoming == null) return null;

    if (server.scheme != 'https' ||
        server.host.isEmpty ||
        server.userInfo.isNotEmpty ||
        server.port != 443 ||
        (server.path.isNotEmpty && server.path != '/') ||
        server.hasQuery ||
        server.hasFragment) {
      return null;
    }

    if (incoming.scheme != 'https' ||
        incoming.host.toLowerCase() != server.host.toLowerCase() ||
        incoming.port != 443 ||
        incoming.userInfo.isNotEmpty ||
        incoming.hasFragment) {
      return null;
    }

    final segments = incoming.pathSegments;
    if (segments.length != 2 || segments.first != 'reset-password') {
      return null;
    }
    final token = segments.last;
    if (!_tokenPattern.hasMatch(token)) return null;

    final emailParameters = incoming.queryParametersAll['email'];
    if (emailParameters == null || emailParameters.length != 1) return null;
    final email = emailParameters.single.trim().toLowerCase();
    if (email.length > 254 || !_emailPattern.hasMatch(email)) return null;

    return PasswordResetLink(token: token, email: email);
  }
}
