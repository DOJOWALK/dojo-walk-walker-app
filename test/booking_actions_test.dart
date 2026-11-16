import 'package:flutter_test/flutter_test.dart';
import 'package:dojo_walk_walker_app/booking_actions.dart';

void main() {
  group('walkerActionForBookingStatus', () {
    test('confirmed bookings can be started', () {
      expect(walkerActionForBookingStatus('confirmed'), 'start');
    });
    test('in-progress bookings can be completed', () {
      expect(walkerActionForBookingStatus('in_progress'), 'complete');
    });
    test('completed and unknown bookings expose no action', () {
      expect(walkerActionForBookingStatus('completed'), isNull);
      expect(walkerActionForBookingStatus('cancelled'), isNull);
      expect(walkerActionForBookingStatus(null), isNull);
    });
  });
  group('walkerCanCompleteNow', () {
    final startedAt = DateTime.utc(2026, 11, 16, 10).toIso8601String();

    test('blocks completion before five minutes', () {
      expect(
        walkerCanCompleteNow(startedAt, now: DateTime.utc(2026, 11, 16, 10, 4, 59)),
        isFalse,
      );
    });

    test('allows completion at five minutes and afterwards', () {
      expect(
        walkerCanCompleteNow(startedAt, now: DateTime.utc(2026, 11, 16, 10, 5)),
        isTrue,
      );
      expect(
        walkerCanCompleteNow(startedAt, now: DateTime.utc(2026, 11, 16, 10, 6)),
        isTrue,
      );
    });

    test('fails closed for missing or invalid start timestamps', () {
      expect(walkerCanCompleteNow(null), isFalse);
      expect(walkerCanCompleteNow('not-a-date'), isFalse);
    });
  });

}
