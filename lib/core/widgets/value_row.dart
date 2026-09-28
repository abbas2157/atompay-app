import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A read-only label/value row (money right-aligned, tabular).
class ValueRow extends StatelessWidget {
  const new({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.x8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: text.bodySmall)),
            const SizedBox(width: Space.x16),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: text.figure(
                  text.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
