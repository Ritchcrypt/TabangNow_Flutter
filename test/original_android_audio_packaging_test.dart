import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all ORIGINAL Android alert resources are preserved for release', () {
    const sources = <String, int>{
      'tabangnow_notification_v4.mp3': 513024,
      'tabangnow_moderate_v1.mp3': 99840,
      'tabangnow_low_v1.mp3': 65201,
      'tabangnow_notification.wav': 247002,
    };
    const keepRule = 'android/app/src/main/res/raw/'
        'keep_tabangnow_notification_sounds.xml';
    final xml = File(keepRule).readAsStringSync();
    for (final entry in sources.entries) {
      final file = File('android/app/src/main/res/raw/${entry.key}');
      expect(file.existsSync(), isTrue, reason: 'Missing ORIGINAL ${entry.key}');
      expect(file.lengthSync(), entry.value,
          reason: 'Original ${entry.key} changed unexpectedly');
      final resource = entry.key.replaceAll(RegExp(r'\.(mp3|wav)$'), '');
      expect(xml.contains('@raw/$resource'), isTrue,
          reason: 'R8 keep rule must preserve original $resource');
    }
    final buildScript = File('tool/build_android_release.ps1').readAsStringSync();
    expect(buildScript.contains('TABANGNOW_ORIGINAL_SOUND_RELEASE_GATE'), isTrue);
    expect(buildScript.contains('audioZip.Entries'), isTrue);
    expect(buildScript.contains('ComputeHash'), isTrue);
  });
}