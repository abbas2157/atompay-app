import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Six numeric boxes backed by one text field, so paste and SMS/OTP autofill
/// fill all six and screen readers read it as one field. Calls [onCompleted]
/// when the sixth digit lands.
class OtpField extends StatefulWidget {
  const new({
    required this.controller,
    required this.semanticLabel,
    super.key,
    this.errorText,
    this.onCompleted,
    this.enabled = true,
    this.autofocus = true,
  });

  static const length = 6;

  final TextEditingController controller;
  final String semanticLabel;
  final String? errorText;
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool autofocus;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _changed() {
    _rebuild();
    final code = widget.controller.text;
    if (code.length == OtpField.length) widget.onCompleted?.call(code);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = context.text;
    final code = widget.controller.text;
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            // The real input: invisible, but focusable, pasteable and
            // autofillable.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(OtpField.length),
                  ],
                  showCursor: false,
                  enableInteractiveSelection: true,
                  decoration: InputDecoration(
                    semanticCounterText: '',
                    labelText: widget.semanticLabel,
                    border: InputBorder.none,
                    filled: false,
                    counterText: '',
                  ),
                ),
              ),
            ),
            ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.enabled ? _focus.requestFocus : null,
                child: Row(
                  children: [
                    for (var i = 0; i < OtpField.length; i++) ...[
                      if (i > 0) const SizedBox(width: Space.x8),
                      Expanded(
                        child: _Box(
                          digit: i < code.length ? code[i] : '',
                          active:
                              _focus.hasFocus &&
                              (i == code.length ||
                                  (i == OtpField.length - 1 &&
                                      code.length == OtpField.length)),
                          error: hasError,
                          tokens: t,
                          style: text.title,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: Space.x8),
          Text(
            widget.errorText!,
            style: text.bodySmall.copyWith(color: AppColors.coral),
          ),
        ],
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const new({
    required this.digit,
    required this.active,
    required this.error,
    required this.tokens,
    required this.style,
  });

  final String digit;
  final bool active;
  final bool error;
  final AppTokens tokens;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? AppColors.coral
        : active
        ? AppColors.violet
        : tokens.line;
    return AnimatedContainer(
      duration: Motion.short,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.paper,
        borderRadius: BorderRadius.circular(Radii.input),
        border: Border.all(color: color, width: active || error ? 2 : 1),
      ),
      child: Text(digit, style: style),
    );
  }
}
