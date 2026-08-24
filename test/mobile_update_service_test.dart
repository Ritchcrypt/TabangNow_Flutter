import 'package:flutter_test/flutter_test.dart';
import 'package:tabangnow_flutter/services/mobile_update_service.dart';

void main() {
  group('MobileUpdatePolicy', () {
    test('returns none when installed build is current', () {
      expect(
        MobileUpdatePolicy.evaluate(
          currentBuildNumber: 5,
          latestBuildNumber: 5,
          minimumSupportedBuildNumber: 3,
        ),
        MobileUpdateRequirement.none,
      );
    });

    test('returns optional when a newer build exists', () {
      expect(
        MobileUpdatePolicy.evaluate(
          currentBuildNumber: 4,
          latestBuildNumber: 5,
          minimumSupportedBuildNumber: 3,
        ),
        MobileUpdateRequirement.optional,
      );
    });

    test('returns required below the minimum supported build', () {
      expect(
        MobileUpdatePolicy.evaluate(
          currentBuildNumber: 2,
          latestBuildNumber: 5,
          minimumSupportedBuildNumber: 3,
        ),
        MobileUpdateRequirement.required,
      );
    });
  });
}
