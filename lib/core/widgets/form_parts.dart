import 'package:atompay_mobile/core/forms/form_controller.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:flutter/material.dart';

/// The submit button with everything a form shows around it: a general
/// error as a rose note, a 429 countdown, and the busy state.
class SubmitSection extends StatelessWidget {
  const new({
    required this.label,
    required this.status,
    required this.onSubmit,
    this.fieldsOnScreen = const {},
    this.enabled = true,
    this.offline = false,
    this.onRetryReady,
    super.key,
  });

  final String label;
  final FormStatus status;
  final VoidCallback onSubmit;
  final Set<String> fieldsOnScreen;
  final bool enabled;

  /// Submits need a connection (brief §8, offline).
  final bool offline;
  final VoidCallback? onRetryReady;

  @override
  Widget build(BuildContext context) {
    final message = status.generalMessage(fieldsOnScreen);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null) ...[
          Semantics(
            liveRegion: true,
            child: Note(tone: NoteTone.rose, text: message),
          ),
          const SizedBox(height: Space.s12),
        ],
        AppButton.primary(
          offline ? 'Needs a connection' : label,
          large: true,
          block: true,
          busy: status.busy,
          onPressed: !enabled || status.blocked || offline ? null : onSubmit,
        ),
        if (status.blocked) ...[
          const SizedBox(height: Space.s8),
          Center(
            child: RetryCountdown(
              retryAfter: status.retryIn,
              prefix: 'Too many tries. Try again in',
              onDone: onRetryReady,
            ),
          ),
        ],
      ],
    );
  }
}

/// A scrolling form page with the 16 dp gutter, capped width on tablets,
/// and the keyboard kept clear.
class FormPage extends StatelessWidget {
  const new({
    required this.children,
    this.footer,
    this.padding = const EdgeInsets.all(Space.gutter),
    this.controller,
    super.key,
  });

  final List<Widget> children;

  /// Pinned under the scroll view (the action bar).
  final Widget? footer;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: controller,
            padding: padding,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: content,
          ),
        ),
        if (footer != null)
          Container(
            decoration: BoxDecoration(
              color: c.white,
              border: Border(top: BorderSide(color: c.line)),
            ),
            padding: const EdgeInsets.fromLTRB(
              Space.s16,
              Space.s12,
              Space.s16,
              Space.s16,
            ),
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: footer,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Vertical gap helpers on the 2/4/6/8 rhythm.
abstract final class Gap {
  static const s4 = SizedBox(height: Space.s4);
  static const s6 = SizedBox(height: Space.s6);
  static const s8 = SizedBox(height: Space.s8);
  static const s10 = SizedBox(height: Space.s10);
  static const s12 = SizedBox(height: Space.s12);
  static const s14 = SizedBox(height: Space.s14);
  static const s16 = SizedBox(height: Space.s16);
  static const s20 = SizedBox(height: Space.s20);
  static const s24 = SizedBox(height: Space.s24);
  static const s32 = SizedBox(height: Space.s32);
}

/// Moves focus to the first field with an error, in the given order.
void focusFirstError(FormStatus status, Map<String, FocusNode> fields) {
  for (final entry in fields.entries) {
    if (status.field(entry.key) != null) {
      entry.value.requestFocus();
      return;
    }
  }
}
