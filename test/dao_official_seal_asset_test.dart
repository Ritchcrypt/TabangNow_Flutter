import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Official Dao seal is bundled for offline in-app branding', () async {
    final image = await rootBundle.load('assets/branding/dao_official_seal.jpg');
    expect(image.lengthInBytes, greaterThan(1000));
    expect(image.getUint8(0), 0xFF);
    expect(image.getUint8(1), 0xD8);
  });
}