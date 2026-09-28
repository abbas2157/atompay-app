import 'package:atompay_mobile/core/utils/money.dart';
import 'package:atompay_mobile/core/widgets/app_text_field.dart';
import 'package:atompay_mobile/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// `application_status` → words. Unknown values fall back to the raw text.
String applicationStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'pending' => l10n.statusPending,
      'approved' => l10n.statusApproved,
      'conditional' => l10n.statusConditional,
      'rejected' => l10n.statusNotApproved,
      _ => status,
    };

/// Digits only, shown as `PKR 200,000` while typing.
class MoneyField extends StatelessWidget {
  const new({
    required this.label,
    required this.controller,
    super.key,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      controller: controller,
      errorText: errorText,
      helperText: helperText,
      hintText: '0',
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      inputFormatters: [MoneyInputFormatter()],
      prefixText: 'PKR ',
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
