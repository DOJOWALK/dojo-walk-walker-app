/// Normalizes a valid Indian mobile number to E.164 (+91XXXXXXXXXX).
/// Accepts a 10-digit national number or the same number prefixed by 91.
String? normalizeIndianMobileNumber(String input) {
  final digits = input.replaceAll(RegExp(r'\\D'), '');
  if (digits.length == 10 && RegExp(r'^[6-9]\\d{9}$').hasMatch(digits)) {
    return '+91$digits';
  }
  if (digits.length == 12 && RegExp(r'^91[6-9]\\d{9}$').hasMatch(digits)) {
    return '+$digits';
  }
  return null;
}
