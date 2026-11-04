import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('evidence capture uses an embedded photo-only camera screen', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final cameraScreen = File(
      'lib/screens/photo_capture_screen.dart',
    ).readAsStringSync();
    final incident = File(
      'lib/screens/report_incident_screen.dart',
    ).readAsStringSync();
    final complaintCreate = File(
      'lib/screens/resident_complaint_create_screen.dart',
    ).readAsStringSync();
    final complaintDetail = File(
      'lib/screens/resident_complaint_detail_screen.dart',
    ).readAsStringSync();

    expect(pubspec, contains('camera:'));
    expect(pubspec, isNot(contains('image_picker:')));

    expect(cameraScreen, contains('CameraPreview(controller)'));
    expect(cameraScreen, contains('controller.takePicture()'));
    expect(cameraScreen, contains('enableAudio: false'));
    expect(cameraScreen, contains("'Retake'"));
    expect(cameraScreen, contains("'Use Photo'"));
    expect(cameraScreen, isNot(contains('startVideoRecording')));
    expect(cameraScreen, isNot(contains('recordVideo')));

    expect(incident, contains('Take Evidence Photo'));
    expect(incident, contains('Choose Existing Evidence'));

    expect(complaintCreate, contains('Take Supporting Feedback Photo'));
    expect(complaintCreate, contains('Choose Existing Picture'));

    expect(complaintDetail, contains('Take Action Proof Photo'));
    expect(complaintDetail, contains('Choose Existing Proof Picture'));
  });

  test('platform configuration is camera-only for this feature', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(manifest, contains('android.permission.CAMERA'));
    expect(infoPlist, contains('<key>NSCameraUsageDescription</key>'));
    expect(
      infoPlist,
      isNot(contains('<key>NSMicrophoneUsageDescription</key>')),
    );
  });
}
