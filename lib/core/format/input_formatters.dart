import 'package:atompay_mobile/core/format/money.dart';
import 'package:flutter/services.dart';

/// Types "200,000" as the customer types "200000".
class GroupedDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final v = parseRupees(newValue.text);
    final text = v == null ? '' : grouped(v);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
