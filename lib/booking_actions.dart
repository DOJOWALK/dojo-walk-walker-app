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

/// Keeps the completion control disabled until five minutes after the
/// backend-recorded start time. Firebase remains authoritative.
bool walkerCanCompleteNow(String? startedAt, {DateTime? now}) {
  if (startedAt == null) return false;
  try {
    final started = DateTime.parse(startedAt).toUtc();
    final availableAt = started.add(const Duration(minutes: 5));
    return !(now ?? DateTime.now()).toUtc().isBefore(availableAt);
  } on FormatException {
    return false;
  }
}
