import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:flutter/material.dart';

/// A centred dialog (canvas `.dlg`): title, body, then stacked buttons.
/// Returns true for [confirm], false or null otherwise.
///
/// - Plain: primary [confirm] first, then a ghost [cancel].
/// - [destructive]: a ghost [cancel] first, then a filled rose [confirm]
///   (Sign out, Sign out everywhere).
/// - [cancelIsDefault]: a primary [cancel] first, then [confirm] as a
///   ghost button, in rose when [destructive] (Discard).
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
    barrierColor: context.colors.ink.withValues(alpha: 0.45),
    builder: (context) {
      final c = context.colors;
      final t = context.text;
      void yes() => Navigator.of(context).pop(true);
      void no() => Navigator.of(context).pop(false);
      final List<Widget> buttons;
      if (cancel != null && cancelIsDefault) {
        buttons = [
          AppButton.primary(cancel, block: true, onPressed: no),
          if (destructive)
            AppButton.ghostDanger(confirm, block: true, onPressed: yes)
          else
            AppButton.ghost(confirm, block: true, onPressed: yes),
        ];
      } else if (cancel != null && destructive) {
        buttons = [
          AppButton.ghost(cancel, block: true, onPressed: no),
          AppButton.danger(confirm, block: true, onPressed: yes),
        ];
      } else {
        buttons = [
          if (destructive)
            AppButton.danger(confirm, block: true, onPressed: yes)
          else
            AppButton.primary(confirm, block: true, onPressed: yes),
          if (cancel != null)
            AppButton.ghost(cancel, block: true, onPressed: no),
        ];
      }
      return Dialog(
        insetPadding: const EdgeInsets.all(Space.s24),
        backgroundColor: c.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: 0.25),
                blurRadius: 60,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.s22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: t.h4.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: Space.s12),
                  Text(body, style: t.small.copyWith(color: c.body)),
                ],
                const SizedBox(height: Space.s18),
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) const SizedBox(height: Space.s8),
                  buttons[i],
                ],
              ],
            ),
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
  body: "What you've typed here won't be saved.",
  confirm: 'Discard',
  cancel: 'Keep editing',
  cancelIsDefault: true,
  destructive: true,
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
