import 'package:atompay_mobile/core/utils/app_clock.dart';
import 'package:flutter/services.dart';

/// Pakistani CNIC and mobile helpers. They mirror the server's rules for a
/// quick check while typing; the server's normalised value is what counts.
abstract final class Pk {
  /// 13 digits, first digit 1–7.
  static bool isCnic(String text) =>
      RegExp(r'^[1-7]\d{12}$').hasMatch(digits(text));

  /// `42101-9876543-2`.
  static String formatCnic(String text) {
    final d = digits(text);
    if (d.length != 13) return text;
    return '${d.substring(0, 5)}-${d.substring(5, 12)}-${d.substring(12)}';
  }

  /// `03` + 9 digits, after normalising `+92`, `92` and a missing `0`.
  static bool isMobile(String text) => normaliseMobile(text) != null;

  static String? normaliseMobile(String text) {
    var d = digits(text);
    if (d.startsWith('92') && d.length == 12) d = '0${d.substring(2)}';
    if (d.startsWith('3') && d.length == 10) d = '0$d';
    return RegExp(r'^03\d{9}$').hasMatch(d) ? d : null;
  }

  /// `0300 1234567`.
  static String formatMobile(String text) {
    final m = normaliseMobile(text);
    return m == null ? text : '${m.substring(0, 4)} ${m.substring(4)}';
  }

  static bool isEmail(String text) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text.trim());

  static String digits(String text) => text.replaceAll(RegExp(r'\D'), '');

  /// 18 or older on [today].
  static bool isAdult(DateTime dob, {DateTime? today}) {
    final t = today ?? AppClock.now();
    final eighteen = DateTime(dob.year + 18, dob.month, dob.day);
    return !eighteen.isAfter(DateTime(t.year, t.month, t.day));
  }
}

/// Types dashes into a CNIC as the customer types: `42101-9876543-2`.
class CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = Pk.digits(newValue.text);
    final capped = d.length > 13 ? d.substring(0, 13) : d;
    final b = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 5 || i == 12) b.write('-');
      b.write(capped[i]);
    }
    final text = b.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Groups a rupee amount with commas as it is typed: `120,000`.
class RupeeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = Pk.digits(newValue.text);
    if (d.isEmpty) return TextEditingValue.empty;
    final capped = d.length > 9 ? d.substring(0, 9) : d;
    final n = int.parse(capped);
    final text = n.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
