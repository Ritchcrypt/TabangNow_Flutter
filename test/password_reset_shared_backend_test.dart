import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabangnow_flutter/services/auth_service.dart';

void main() {
  test('public mobile reset uses the shared Laravel endpoint without token', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/auth/forgot-password');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(request.headers['Content-Type'], 'application/json');
      expect(jsonDecode(request.body), {'email': 'resident@example.com'});
      return http.Response(
        jsonEncode({'message': 'A reset link will be sent if the account exists.'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = AuthService(client: client);
    expect(
      await service.requestPasswordReset(email: ' resident@example.com '),
      'A reset link will be sent if the account exists.',
    );
    client.close();
  });

  test('public mobile reset shows safe delivery error when Brevo is down', () async {
    final client = MockClient((request) async => http.Response(
      jsonEncode({'message': 'Password reset email is temporarily unavailable. Please try again later.'}),
      503,
      headers: {'content-type': 'application/json'},
    ));
    final service = AuthService(client: client);
    await expectLater(
      service.requestPasswordReset(email: 'resident@example.com'),
      throwsA(isA<AuthException>().having(
        (error) => error.statusCode, 'status code', 503,
      )),
    );
    client.close();
  });

  test('public mobile reset does not reveal an unknown account', () async {
    final client = MockClient((request) async => http.Response(
      jsonEncode({'message': 'A reset link will be sent if the account exists.'}),
      200,
      headers: {'content-type': 'application/json'},
    ));
    final service = AuthService(client: client);
    expect(
      await service.requestPasswordReset(email: 'unknown@example.com'),
      'A reset link will be sent if the account exists.',
    );
    client.close();
  });
}
