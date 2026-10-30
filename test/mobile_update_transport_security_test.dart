import 'package:flutter_test/flutter_test.dart';
import 'package:tabangnow_flutter/services/mobile_update_service.dart';

void main() {
  group('C21 mobile update URL hardening', () {
    test('accepts public HTTPS API root, not the old Railway fallback', () {
      expect(MobileUpdateTransportPolicy.isAllowedApiRoot(
        'https://tabangnow.example.org', allowLoopbackHttp: false), isTrue);
      expect(MobileUpdateTransportPolicy.isAllowedApiRoot(
        '', allowLoopbackHttp: false), isFalse);
      expect(MobileUpdateTransportPolicy.isAllowedApiRoot(
        'http://tabangnow.example.org', allowLoopbackHttp: false), isFalse);
      expect(MobileUpdateTransportPolicy.isAllowedApiRoot(
        'https://tabangnow.example.org/api/v1', allowLoopbackHttp: false), isFalse);
    });
    test('permits only explicit loopback HTTP in development', () {
      expect(MobileUpdateTransportPolicy.isAllowedApiRoot(
        'http://127.0.0.1:8000', allowLoopbackHttp: true), isTrue);
      expect(MobileUpdateTransportPolicy.isAllowedApiRoot(
        'http://127.0.0.1:8000', allowLoopbackHttp: false), isFalse);
      expect(MobileUpdateTransportPolicy.isAllowedApiRoot(
        'http://192.168.1.20:8000', allowLoopbackHttp: true), isFalse);
    });
    test('rejects unsafe APK download URLs', () {
      expect(MobileUpdateTransportPolicy.isAllowedDownload(
        'https://github.com/owner/repo/releases/download/v1/app.apk'), isTrue);
      for (final url in <String>[
        'http://tabangnow.example.org/app.apk',
        'javascript:alert(1)',
        'intent://app.example',
        'https://localhost/app.apk',
        'https://127.0.0.1/app.apk',
        'https://user:secret@tabangnow.example.org/app.apk',
        'https://tabangnow.example.org:8443/app.apk',
        'https://tabangnow.example.org/app.apk\n',
      ]) {
        expect(MobileUpdateTransportPolicy.isAllowedDownload(url), isFalse,
            reason: 'Unsafe URL: $url');
      }
    });
  });
}
