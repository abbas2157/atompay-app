import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A read-only field that opens a picker (date, city, option list).
class PickerField extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.icon,
    required this.onTap,
    super.key,
    this.errorText,
  });

  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: Text(label.toUpperCase(), style: text.eyebrow)),
        const SizedBox(height: Space.x8),
        Semantics(
          button: true,
          label: label,
          value: value,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.input),
            child: InputDecorator(
              decoration: InputDecoration(
                errorText: errorText,
                suffixIcon: Icon(icon, color: t.muted),
              ),
              child: Text(
                value ?? placeholder,
                style: text.body.copyWith(
                  color: value == null ? t.muted : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
