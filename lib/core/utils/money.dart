import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _grouped = NumberFormat.decimalPattern('en_US');

/// Money: int rupees → `PKR 45,000` (handbook §4.7). Never a double.
String pkr(int amount) => 'PKR ${_grouped.format(amount)}';

/// Digits only, grouped as you type (`200,000`). Pair with a `PKR` prefix.
class MoneyInputFormatter extends TextInputFormatter {
  /// Longest amount the API accepts is 100,000,000 (9 digits).
  static const maxDigits = 9;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    digits = digits.replaceFirst(RegExp('^0+(?=.)'), '');
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    final text = digits.isEmpty ? '' : _grouped.format(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// `200,000` → 200000; empty → null.
  static int? parse(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? null : int.parse(digits);
  }

  static String format(int? amount) =>
      amount == null ? '' : _grouped.format(amount);
}
