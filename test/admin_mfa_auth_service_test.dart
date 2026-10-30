import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabangnow_flutter/services/auth_service.dart';

void main() {
  test('admin MFA challenge never creates a session token', () async {
    final service = AuthService(client: MockClient((request) async {
      expect(request.url.path, '/api/v1/auth/login');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['mfa_code'], isNull);
      return http.Response(
        jsonEncode({'mfa_required': true, 'message': 'Enter code'}),
        202,
        headers: {'content-type': 'application/json'},
      );
    }));
    final response = await service.login(
      email: 'admin@example.test',
      password: 'password',
      deviceName: 'Android',
    );
    expect(response['mfa_required'], true);
    expect(response.containsKey('access_token'), false);
  });
}
