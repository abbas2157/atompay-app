import 'package:flutter/services.dart';

/// Pakistani CNIC and mobile helpers, matching the server's rules
/// (handbook §9.1). The server's normalised value is still the one to store.
abstract final class Pk {
  static const _provinces = {'1', '2', '3', '4', '5', '6', '7'};

  static String digits(String? v) => (v ?? '').replaceAll(RegExp(r'\D'), '');

  // ---- CNIC: 13 digits, first digit 1–7, not all zeros ----

  static String normalizeCnic(String? v) => digits(v);

  static bool isValidCnic(String? v) {
    final d = digits(v);
    return d.length == 13 &&
        _provinces.contains(d[0]) &&
        d.replaceAll('0', '').isNotEmpty;
  }

  static String formatCnic(String? v) {
    final d = digits(v);
    return d.length == 13
        ? '${d.substring(0, 5)}-${d.substring(5, 12)}-${d.substring(12)}'
        : (v ?? '');
  }

  // ---- Mobile: every form → 03XXXXXXXXX, or '' if not a PK mobile ----

  static String normalizeMobile(String? v) {
    var d = digits(v);
    for (final p in ['0092', '92']) {
      if (d.startsWith(p) && d.length > p.length) {
        d = d.substring(p.length);
        break;
      }
    }
    if (RegExp(r'^3\d{9}$').hasMatch(d)) d = '0$d';
    return RegExp(r'^03\d{9}$').hasMatch(d) ? d : '';
  }

  static bool isValidMobile(String? v) => normalizeMobile(v).isNotEmpty;

  static String formatMobile(String? v) {
    final d = normalizeMobile(v);
    return d.isEmpty ? (v ?? '') : '${d.substring(0, 4)} ${d.substring(4)}';
  }

  static bool isEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

  /// For the sign-up / forgot "email or mobile" field.
  static bool looksLikeMobile(String v) =>
      RegExp(r'^[\d\s+\-()]+$').hasMatch(v.trim());
}

/// Age check for the DOB picker (server: at least 18 years old).
bool isAdult(DateTime dob, {DateTime? now}) {
  final t = now ?? DateTime.now();
  return !DateTime(dob.year + 18, dob.month, dob.day).isAfter(t);
}

/// `#####-#######-#` as you type. Keeps at most 13 digits.
class CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = Pk.digits(newValue.text);
    if (d.length > 13) d = d.substring(0, 13);
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 5 || i == 12) b.write('-');
      b.write(d[i]);
    }
    return _collapsed(b.toString());
  }
}

/// `03## #######` as you type. A pasted `+92 300…` / `92300…` / `300…` is
/// normalised to the local form first.
class MobileInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = Pk.normalizeMobile(newValue.text);
    var d = normalized.isNotEmpty ? normalized : Pk.digits(newValue.text);
    if (d.length > 11) d = d.substring(0, 11);
    final text = d.length > 4 ? '${d.substring(0, 4)} ${d.substring(4)}' : d;
    return _collapsed(text);
  }
}

/// Email-or-mobile field: formats only when the input is all digits, `+`,
/// spaces or dashes and could be a mobile; leaves anything else untouched.
class LoginInputFormatter extends TextInputFormatter {
  final _mobile = MobileInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty || !Pk.looksLikeMobile(text)) return newValue;
    // Leave `+92…` alone while it's being typed; format once it's complete.
    if (text.trimLeft().startsWith('+') && !Pk.isValidMobile(text)) {
      return newValue;
    }
    return _mobile.formatEditUpdate(oldValue, newValue);
  }
}

TextEditingValue _collapsed(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);
