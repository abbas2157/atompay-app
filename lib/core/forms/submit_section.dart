import 'package:atompay_mobile/core/forms/form_controller.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/countdown.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:flutter/material.dart';

/// The general error (or `429` countdown) above a form's primary button.
/// The button is disabled while the request is in flight or rate limited.
class SubmitSection extends StatelessWidget {
  const new({
    required this.status,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final FormStatus status;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CountdownBuilder(
      until: status.blockedUntil,
      builder: (context, secondsLeft) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (secondsLeft > 0)
            FormErrorText(l10n.rateLimited(secondsLeft))
          else if (status.hasGeneralError)
            FormErrorText(apiErrorText(l10n, status.error!)),
          PrimaryButton(
            label: label,
            loading: status.busy,
            onPressed: secondsLeft > 0 ? null : onPressed,
          ),
        ],
      ),
    );
  }
}
