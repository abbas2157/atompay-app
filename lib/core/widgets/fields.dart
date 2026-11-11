import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Label, input, then a hint or an inline error. The error is a live region
/// so it is announced as soon as it appears.
class AppTextField extends StatelessWidget {
  const new({
    required this.label,
    this.controller,
    this.focusNode,
    this.hint,
    this.placeholder,
    this.error,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.prefixText,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.large = false,
    super.key,
  });

  /// Canvas `.field.big`: 60 high, the value at 24/800, the prefix at
  /// 17/800 (the Calculator's price).
  final bool large;
  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? placeholder;
  final String? error;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final String? prefixText;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final hasError = error != null && error!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.label),
        const SizedBox(height: 7),
        FocusRing(
          builder: ({required focused}) => TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            enabled: enabled,
            readOnly: readOnly,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            inputFormatters: inputFormatters,
            maxLines: obscureText ? 1 : maxLines,
            minLines: minLines,
            maxLength: maxLength,
            textCapitalization: textCapitalization,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: large ? t.h1b.copyWith(letterSpacing: -0.5) : t.body,
            decoration: InputDecoration(
              constraints: large ? const BoxConstraints(minHeight: 60) : null,
              hintText: placeholder,
              // Always shown (prefixText only appears once focused).
              prefixIcon: prefixText == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: 14, right: 8),
                      child: Text(
                        prefixText!,
                        style: (large ? t.h4 : t.body).copyWith(
                          color: c.muted,
                          fontWeight: large ? FontWeight.w800 : FontWeight.w700,
                        ),
                      ),
                    ),
              prefixIconConstraints: const BoxConstraints(),
              // Read by screen readers as the field's name.
              semanticCounterText: '',
              counterText: maxLength == null ? null : '',
              fillColor: hasError
                  ? c.dangerWash
                  : (focused
                        ? c.white
                        : (enabled && !readOnly ? c.field : c.surface)),
              enabledBorder: hasError
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.input),
                      borderSide: BorderSide(color: c.danger),
                    )
                  : null,
              suffixIcon: suffix,
            ).applyDefaults(Theme.of(context).inputDecorationTheme),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: Space.s6),
            child: Semantics(
              liveRegion: true,
              child: Text(error!, style: t.small.copyWith(color: c.rose)),
            ),
          )
        else if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.s6),
            child: Text(
              hint!,
              style: t.tiny.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}

/// A password field with a 48 dp show/hide toggle.
class PasswordField extends StatefulWidget {
  const new({
    required this.label,
    this.controller,
    this.focusNode,
    this.error,
    this.hint,
    this.textInputAction,
    this.autofillHints = const [AutofillHints.password],
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? error;
  final String? hint;
  final TextInputAction? textInputAction;
  final Iterable<String> autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) => AppTextField(
    label: widget.label,
    controller: widget.controller,
    focusNode: widget.focusNode,
    error: widget.error,
    hint: widget.hint,
    obscureText: !_shown,
    keyboardType: TextInputType.visiblePassword,
    textInputAction: widget.textInputAction,
    autofillHints: widget.autofillHints,
    onChanged: widget.onChanged,
    onSubmitted: widget.onSubmitted,
    suffix: AppIconButton(
      icon: _shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      label: _shown ? 'Hide password' : 'Show password',
      size: 22,
      color: context.colors.body,
      onPressed: () => setState(() => _shown = !_shown),
    ),
  );
}

/// Six boxes over one hidden field, so paste and the SMS/WhatsApp autofill
/// fill all six at once.
class OtpField extends StatefulWidget {
  const new({
    required this.onChanged,
    this.controller,
    this.focusNode,
    this.label = 'Verification code',
    this.error,
    this.hint = 'Pasting the code fills all six boxes.',
    this.onCompleted,
    this.autofocus = true,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String label;
  final String? error;
  final String? hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _focus.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _focus.removeListener(_rebuild);
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final code = _controller.text;
    final hasError = widget.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Text(widget.label, style: t.label)),
        const SizedBox(height: Space.s6),
        Stack(
          children: [
            // The real input: transparent, on top, so taps and paste reach it.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  showCursor: false,
                  enableInteractiveSelection: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(counterText: ''),
                  onChanged: (v) {
                    widget.onChanged(v);
                    if (v.length == 6) widget.onCompleted?.call(v);
                  },
                ),
              ),
            ),
            IgnorePointer(
              child: Semantics(
                label: '${widget.label}, 6 digits, ${code.length} entered',
                excludeSemantics: true,
                child: Row(
                  children: [
                    for (var i = 0; i < 6; i++) ...[
                      if (i > 0) const SizedBox(width: Space.s8),
                      Expanded(
                        child: Container(
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _isActive(i, code)
                                ? c.white
                                : (hasError ? c.dangerWash : c.field),
                            borderRadius: BorderRadius.circular(Radii.note),
                            border: Border.all(
                              color: _isActive(i, code)
                                  ? c.primary
                                  : (hasError ? c.danger : c.line2),
                              width: _isActive(i, code) ? 2 : 1,
                            ),
                            boxShadow: _isActive(i, code)
                                ? [
                                    BoxShadow(
                                      color: c.primarySoft,
                                      spreadRadius: 3,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            i < code.length ? code[i] : '',
                            style: t.h1b,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: Space.s6),
            child: Semantics(
              liveRegion: true,
              child: Text(
                widget.error!,
                style: t.small.copyWith(color: c.rose),
              ),
            ),
          )
        else if (widget.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.s6),
            child: Text(
              widget.hint!,
              style: t.tiny.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  bool _isActive(int i, String code) =>
      _focus.hasFocus && i == code.length.clamp(0, 5);
}

/// Canvas `.input:focus-within`: a 3 dp primary-soft ring outside the
/// border while anything inside has focus.
class FocusRing extends StatefulWidget {
  const new({required this.builder, super.key});

  final Widget Function({required bool focused}) builder;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focused = f),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.input),
          boxShadow: _focused
              ? [BoxShadow(color: c.primarySoft, spreadRadius: 3)]
              : const [],
        ),
        child: widget.builder(focused: _focused),
      ),
    );
  }
}
