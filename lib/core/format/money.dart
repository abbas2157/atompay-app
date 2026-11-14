import 'package:intl/intl.dart';

final _grouped = NumberFormat.decimalPattern('en_US');

/// Formats whole rupees the way the site and Atomshop do: `Rs. 157,999`.
/// The app formats money; it never calculates it.
String rs(int rupees) => 'Rs. ${_grouped.format(rupees)}';

/// `157,999` without the prefix.
String grouped(int value) => _grouped.format(value);

/// How a screen reader should say an amount: "Rupees 15,666".
String rsSpoken(int rupees) => 'Rupees ${_grouped.format(rupees)}';

/// Parses what a customer typed into a money field ("1,20,000", "120000").
int? parseRupees(String text) {
  final digits = text.replaceAll(RegExp('[^0-9]'), '');
  if (digits.isEmpty || digits.length > 12) return null;
  return int.parse(digits);
}
