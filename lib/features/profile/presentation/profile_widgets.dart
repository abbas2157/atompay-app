import 'package:atompay_mobile/core/models/kyc_status.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/status.dart';
import 'package:atompay_mobile/features/profile/data/profile_models.dart';
import 'package:atompay_mobile/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

extension KycStatusUi on KycStatus {
  String label(AppLocalizations l10n) => switch (this) {
    KycStatus.notStarted => l10n.statusNotStarted,
    KycStatus.pending => l10n.statusPending,
    KycStatus.verified => l10n.statusVerified,
    KycStatus.rejected => l10n.statusRejected,
    KycStatus.unknown => l10n.statusUnknown,
  };

  StatusTone get tone => switch (this) {
    KycStatus.verified => StatusTone.ok,
    KycStatus.pending => StatusTone.pending,
    KycStatus.rejected => StatusTone.blocked,
    KycStatus.notStarted || KycStatus.unknown => StatusTone.neutral,
  };
}

/// A 4:3 document preview: the image, or a dashed placeholder, with the
/// label and an "uploaded" tick (handbook §4.6).
class DocumentTile extends StatelessWidget {
  const new({
    required this.label,
    required this.image,
    required this.uploaded,
    super.key,
    this.onTap,
    this.action,
    this.errorText,
    this.statusLabel,
  });

  final String label;

  /// Null shows the placeholder.
  final Widget? image;
  final bool uploaded;
  final VoidCallback? onTap;

  /// E.g. "Take photo" / "Retake".
  final Widget? action;
  final String? errorText;

  /// Spoken and shown next to the tick, e.g. "Uploaded".
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = context.text;
    final borderColor = errorText != null ? AppColors.coral : t.line;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: onTap != null,
          label: [label, ?statusLabel].join(', '),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.input),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.input),
                child: image == null
                    ? CustomPaint(
                        painter: _DashedBorder(borderColor),
                        child: Center(
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            color: t.muted,
                          ),
                        ),
                      )
                    : DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(Radii.input),
                        ),
                        child: image,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.x8),
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: text.bodySmall.copyWith(
                  color: t.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (uploaded)
              const ExcludeSemantics(
                child: Icon(Icons.check_circle, size: 18, color: AppColors.ok),
              ),
          ],
        ),
        if (errorText != null)
          Text(
            errorText!,
            style: text.bodySmall.copyWith(color: AppColors.coral),
          ),
        ?action,
      ],
    );
  }
}

class _DashedBorder extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(Radii.input),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

/// Label above value, for the read view.
class InfoRow extends StatelessWidget {
  const new({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.x12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: context.text.eyebrow),
            const SizedBox(height: Space.x4),
            Text(value, style: context.text.body),
          ],
        ),
      ),
    );
  }
}

String documentLabel(AppLocalizations l10n, ProfileDocument doc) =>
    switch (doc) {
      ProfileDocument.cnicFront => l10n.docCnicFront,
      ProfileDocument.cnicBack => l10n.docCnicBack,
      ProfileDocument.selfie => l10n.docSelfie,
    };
