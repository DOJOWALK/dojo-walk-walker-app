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
}
