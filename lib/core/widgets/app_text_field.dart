import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/pk_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Eyebrow label above, paper fill, violet focus, coral error below
/// (handbook §4.6).
class AppTextField extends StatefulWidget {
  const new({
    required this.label,
    super.key,
    this.controller,
    this.errorText,
    this.helperText,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.obscure = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.suffix,
    this.prefixText,
    this.showPasswordLabel,
    this.hidePasswordLabel,
  });

  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final String? helperText;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  /// A password field with a show/hide toggle.
  final bool obscure;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final Widget? suffix;

  /// Fixed text before the input, e.g. `PKR `.
  final String? prefixText;

  /// Semantics labels for the show/hide toggle (localised by the caller).
  final String? showPasswordLabel;
  final String? hidePasswordLabel;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(widget.label.toUpperCase(), style: text.eyebrow),
        ),
        const SizedBox(height: Space.x8),
        Semantics(
          label: widget.label,
          child: TextField(
            controller: widget.controller,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            obscureText: _hidden,
            enableSuggestions: !widget.obscure,
            autocorrect: !widget.obscure,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            inputFormatters: widget.inputFormatters,
            autofillHints: widget.autofillHints,
            maxLines: widget.obscure ? 1 : widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            textCapitalization: widget.textCapitalization,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onTap: widget.onTap,
            style: text.body,
            decoration: InputDecoration(
              semanticCounterText: '',
              counterText: '',
              hintText: widget.hintText,
              prefixText: widget.prefixText,
              prefixStyle: text.body.copyWith(color: context.tokens.muted),
              errorText: widget.errorText,
              helperText: widget.errorText == null ? widget.helperText : null,
              helperMaxLines: 3,
              helperStyle: text.bodySmall,
              suffixIcon: widget.obscure
                  ? IconButton(
                      tooltip: _hidden
                          ? widget.showPasswordLabel
                          : widget.hidePasswordLabel,
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: context.tokens.muted,
                      ),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    )
                  : widget.suffix,
            ),
          ),
        ),
      ],
    );
  }
}

/// Numeric keypad, `#####-#######-#`.
class CnicField extends StatelessWidget {
  const new({
    required this.label,
    required this.controller,
    super.key,
    this.errorText,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      controller: controller,
      errorText: errorText,
      hintText: '42101-1234567-1',
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [CnicInputFormatter()],
      onChanged: onChanged,
    );
  }
}

/// Phone keypad, `03## #######`; normalises a pasted `+92…`.
class MobileField extends StatelessWidget {
  const new({
    required this.label,
    required this.controller,
    super.key,
    this.errorText,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      controller: controller,
      errorText: errorText,
      hintText: '0300 1234567',
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.telephoneNumber],
      inputFormatters: [MobileInputFormatter()],
      onChanged: onChanged,
    );
  }
}

/// Email *or* mobile. Formats as a mobile when the input looks like one.
/// [helperFor] returns the hint for what's typed so far (handbook §5.4).
class LoginField extends StatefulWidget {
  const new({
    required this.label,
    required this.controller,
    super.key,
    this.errorText,
    this.hintText,
    this.helperFor,
    this.emailOnly = false,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.next,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final String? hintText;
  final String? Function(String value)? helperFor;

  /// When the WhatsApp channel is off: email keyboard, no mobile formatting.
  final bool emailOnly;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;

  @override
  State<LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<LoginField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(LoginField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      errorText: widget.errorText,
      hintText: widget.hintText,
      helperText: widget.helperFor?.call(widget.controller.text),
      keyboardType: TextInputType.emailAddress,
      textInputAction: widget.textInputAction,
      autofillHints: [
        AutofillHints.username,
        AutofillHints.email,
        if (!widget.emailOnly) AutofillHints.telephoneNumber,
      ],
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'^\s')),
        if (!widget.emailOnly) LoginInputFormatter(),
      ],
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}
