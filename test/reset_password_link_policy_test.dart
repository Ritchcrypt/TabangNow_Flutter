import 'package:flutter_test/flutter_test.dart';
import 'package:tabangnow_flutter/services/reset_password_link_policy.dart';

void main() {
  const origin = 'https://scsis-production-ac26.up.railway.app';
  const token = 'aBcD0123456789' 'aBcD0123456789' 'aBcD0123456789' 'aBcD0123456789';
  const valid = '$origin/reset-password/$token?email=Resident%40Example.com';

  group('TabangNow trusted password reset links', () {
    test('accepts Laravel reset URL from the configured production origin', () {
      final link = PasswordResetLinkPolicy.parse(valid, apiBaseUrl: origin);
      expect(link, isNotNull);
      expect(link!.token, token);
      expect(link.email, 'resident@example.com');
    });

    test('rejects a different HTTPS origin, including suffix spoofing', () {
      expect(
        PasswordResetLinkPolicy.parse(
          valid.replaceFirst(origin, 'https://scsis-production-ac26.up.railway.app.evil.example'),
          apiBaseUrl: origin,
        ),
        isNull,
      );
    });

    test('rejects HTTP and unconfigured API roots', () {
      expect(
        PasswordResetLinkPolicy.parse(valid.replaceFirst('https:', 'http:'), apiBaseUrl: origin),
        isNull,
      );
      expect(
        PasswordResetLinkPolicy.parse(valid, apiBaseUrl: 'http://127.0.0.1:8000'),
        isNull,
      );
      expect(
        PasswordResetLinkPolicy.parse(valid, apiBaseUrl: '$origin/api'),
        isNull,
      );
    });

    test('rejects malformed paths, tokens, and repeated emails', () {
      expect(
        PasswordResetLinkPolicy.parse(
          valid.replaceFirst('/reset-password/', '/login/'), apiBaseUrl: origin,
        ),
        isNull,
      );
      expect(
        PasswordResetLinkPolicy.parse(
          '$origin/reset-password/short?email=resident%40example.com',
          apiBaseUrl: origin,
        ),
        isNull,
      );
      expect(
        PasswordResetLinkPolicy.parse(
          '$valid&email=other%40example.com', apiBaseUrl: origin,
        ),
        isNull,
      );
    });

    test('rejects fragments, alternate ports, and user info', () {
      expect(
        PasswordResetLinkPolicy.parse('$valid#extra', apiBaseUrl: origin),
        isNull,
      );
      expect(
        PasswordResetLinkPolicy.parse(
          valid.replaceFirst(origin, '$origin:8443'), apiBaseUrl: origin,
        ),
        isNull,
      );
      expect(
        PasswordResetLinkPolicy.parse(
          valid.replaceFirst('https://', 'https://user@'), apiBaseUrl: origin,
        ),
        isNull,
      );
    });
  });
}
