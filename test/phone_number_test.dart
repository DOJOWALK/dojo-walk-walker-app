import 'package:flutter_test/flutter_test.dart';
import 'package:dojo_walk_walker_app/phone_number.dart';

void main() {
  group('normalizeIndianMobileNumber', () {
    test('normalizes a valid ten-digit Indian mobile number', () {
      expect(normalizeIndianMobileNumber('9876543210'), '+919876543210');
    });

    test('accepts country code and common separators', () {
      expect(normalizeIndianMobileNumber('+91 98765-43210'), '+919876543210');
      expect(normalizeIndianMobileNumber('91 9876543210'), '+919876543210');
    });

    test('rejects invalid length and country code', () {
      expect(normalizeIndianMobileNumber('987654321'), isNull);
      expect(normalizeIndianMobileNumber('919876543'), isNull);
      expect(normalizeIndianMobileNumber('0019876543210'), isNull);
    });

    test('rejects Indian mobile numbers outside the 6-9 starting range', () {
      expect(normalizeIndianMobileNumber('5876543210'), isNull);
      expect(normalizeIndianMobileNumber('987654321a'), isNull);
    });
  });
}
