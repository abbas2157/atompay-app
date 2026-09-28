import 'package:atompay_mobile/core/forms/form_controller.dart';
import 'package:atompay_mobile/core/forms/submit_section.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/countdown.dart';
import 'package:atompay_mobile/core/widgets/otp_field.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:flutter/material.dart';

/// The shared body of both "enter your code" screens: the sent-to line, six
/// boxes, the submit button and a resend link with its countdown.
class CodeEntry extends StatelessWidget {
  const new({
    required this.sentTo,
    required this.code,
    required this.status,
    required this.codeError,
    required this.resendAt,
    required this.submitLabel,
    required this.onSubmit,
    required this.onResend,
    super.key,
  });

  final String sentTo;
  final TextEditingController code;
  final FormStatus status;
  final String? codeError;
  final DateTime resendAt;
  final String submitLabel;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(sentTo, style: context.text.body),
        const SizedBox(height: Space.x24),
        OtpField(
          controller: code,
          semanticLabel: l10n.codeFieldLabel,
          errorText: codeError,
          enabled: !status.busy,
          onCompleted: (_) => onSubmit(),
        ),
        const SizedBox(height: Space.x24),
        SubmitSection(status: status, label: submitLabel, onPressed: onSubmit),
        const SizedBox(height: Space.x16),
        Center(
          child: CountdownBuilder(
            until: resendAt,
            builder: (context, left) => TextButton(
              onPressed: left > 0 || status.busy ? null : onResend,
              child: Text(left > 0 ? l10n.resendIn(left) : l10n.resendCode),
            ),
          ),
        ),
      ],
    );
  }
}
