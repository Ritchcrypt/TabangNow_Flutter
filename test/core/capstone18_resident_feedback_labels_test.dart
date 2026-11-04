import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reports use Resident Feedback terminology without changing API keys',
    () {
      final reportsSource =
          File('lib/screens/reports_screen.dart').readAsStringSync();

      final serviceSource =
          File('lib/services/report_service.dart').readAsStringSync();

      final combinedSource = '$reportsSource\n$serviceSource';

      /*
       * Patch 05B may either:
       *
       * 1. expose the metric using the public label "Resident Feedback", or
       * 2. remove the old complaint-specific user-facing control entirely.
       *
       * Both are valid. What is NOT valid is exposing the old
       * "Complaint / Complaints" terminology as a user-facing Reports label.
       */
      final hasResidentFeedbackLabel =
          reportsSource.contains('Resident Feedback');

      final hasLegacyComplaintUi = RegExp(
        r'''['"](?:Complaint|Complaints|Complaint Report|Complaint PDF)['"]''',
      ).hasMatch(reportsSource);

      expect(
        hasResidentFeedbackLabel || !hasLegacyComplaintUi,
        isTrue,
        reason:
            'Reports must use Resident Feedback terminology when the metric '
            'is user-facing, or omit the old complaint-specific UI entirely.',
      );

      /*
       * UI terminology must never rename the established backend contract.
       *
       * Existing identifiers may include:
       *   resident_complaints
       *   complaints
       *   resident-complaints
       *
       * We specifically protect against changing those into a new
       * resident_feedback API/storage identifier.
       */
      expect(
        combinedSource.contains('resident_feedback'),
        isFalse,
        reason:
            'Resident Feedback is a UI label only; established API/storage '
            'identifiers must not be renamed to resident_feedback.',
      );

      expect(
        combinedSource.contains('resident-feedback'),
        isFalse,
        reason:
            'Resident Feedback must not create a replacement API endpoint '
            'named resident-feedback.',
      );
    },
  );
}
