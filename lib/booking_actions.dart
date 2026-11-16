/// Returns the only valid next UI action for a known walker booking state.
/// Backend authorization remains the source of truth.
String? walkerActionForBookingStatus(String? status) {
  switch (status) {
    case 'confirmed':
      return 'start';
    case 'in_progress':
      return 'complete';
    default:
      return null;
  }
}
