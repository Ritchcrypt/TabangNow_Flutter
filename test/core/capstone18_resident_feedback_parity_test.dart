import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resident feedback service sends Capstone 18 fields', () {
    final source = File(
      'lib/services/resident_complaint_service.dart',
    ).readAsStringSync();

    for (final field in <String>[
      "'feedback_category'",
      "'feedback_type'",
      "'feedback_subject'",
      "'service_rating'",
    ]) {
      expect(source, contains(field));
    }
  });

  test('resident feedback create screen exposes feedback workflow', () {
    final source = File(
      'lib/screens/resident_complaint_create_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Send Resident Feedback'));
    expect(source, contains('What is this feedback about? *'));
    expect(source, contains('Feedback Type *'));
    expect(source, contains('Subject *'));
    expect(source, contains('Service / Experience Rating'));
    expect(source, contains('Feedback Details *'));
    expect(source, contains('Send Feedback'));
  });
}
