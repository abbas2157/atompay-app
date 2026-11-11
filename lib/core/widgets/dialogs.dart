import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:flutter/material.dart';

/// A centred dialog: title, body, then stacked buttons with the primary
/// one first. Returns true for [confirm], false or null otherwise.
Future<bool> showAppDialog({
  required BuildContext context,
  required String title,
  required String confirm,
  String? body,
  String? cancel,
  bool destructive = false,
  bool barrierDismissible = true,
  bool cancelIsDefault = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) {
      final t = context.text;
      final confirmButton = destructive
          ? AppButton.danger(
              confirm,
              block: true,
              onPressed: () => Navigator.of(context).pop(true),
            )
          : AppButton.primary(
              confirm,
              block: true,
              onPressed: () => Navigator.of(context).pop(true),
            );
      final cancelButton = cancel == null
          ? null
          : (cancelIsDefault
                ? AppButton.primary(
                    cancel,
                    block: true,
                    onPressed: () => Navigator.of(context).pop(false),
                  )
                : AppButton.ghost(
                    cancel,
                    block: true,
                    onPressed: () => Navigator.of(context).pop(false),
                  ));
      final secondConfirm = cancelIsDefault
          ? AppButton.ghost(
              confirm,
              block: true,
              onPressed: () => Navigator.of(context).pop(true),
            )
          : confirmButton;
      return Dialog(
        insetPadding: const EdgeInsets.all(Space.s24),
        child: Padding(
          padding: const EdgeInsets.all(Space.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(title, style: t.h4)),
              if (body != null) ...[
                const SizedBox(height: Space.s8),
                Text(body, style: t.base),
              ],
              const SizedBox(height: Space.s16),
              if (cancelIsDefault && cancelButton != null) ...[
                cancelButton,
                const SizedBox(height: Space.s10),
                secondConfirm,
              ] else ...[
                confirmButton,
                if (cancelButton != null) ...[
                  const SizedBox(height: Space.s10),
                  cancelButton,
                ],
              ],
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// "Discard your changes?" with Keep editing as the default. True means
/// discard.
Future<bool> confirmDiscard(BuildContext context) => showAppDialog(
  context: context,
  title: 'Discard your changes?',
  body: "What you've typed here will be lost.",
  confirm: 'Discard',
  cancel: 'Keep editing',
  cancelIsDefault: true,
);

/// Guards a form: back asks before throwing away edits, and is blocked
/// while a request is in flight.
class FormExitGuard extends StatelessWidget {
  const new({
    required this.dirty,
    required this.busy,
    required this.child,
    super.key,
  });

  final bool dirty;
  final bool busy;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !busy,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop || busy) return;
      final navigator = Navigator.of(context);
      if (await confirmDiscard(context)) navigator.pop();
    },
    child: child,
  );
}
