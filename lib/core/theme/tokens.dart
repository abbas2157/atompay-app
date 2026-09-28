import 'package:flutter/material.dart';

/// Brand palette (handbook §4.1). Accents are the same in light and dark.
abstract final class AppColors {
  static const nucleus = Color(0xFF050708);
  static const amber = Color(0xFFFAA53A);
  static const coral = Color(0xFFF05465);
  static const rose = Color(0xFFD45771);
  static const violet = Color(0xFF62459B);
  static const royal = Color(0xFF3D5DAB);
  static const ok = Color(0xFF1E9E6A);
  static const white = Color(0xFFFFFFFF);

  /// Progress fills, the stepper connector, the splash and at most one
  /// headline word per screen. Never behind body text.
  static const spectrum = LinearGradient(
    colors: [amber, coral, rose, violet, royal],
  );
}

/// Spacing scale (handbook §4.4).
abstract final class Space {
  static const double x4 = 4;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x20 = 20;
  static const double x24 = 24;
  static const double x32 = 32;
  static const double x40 = 40;

  /// Screen gutter.
  static const double gutter = 20;
}

abstract final class Radii {
  static const double card = 20;
  static const double darkCard = 24;
  static const double input = 12;
  static const double pill = 999;
}

abstract final class Sizes {
  static const double minTouch = 48;
  static const double buttonHeight = 52;
}

abstract final class Motion {
  static const short = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
}

/// Surface colours that change with brightness, read through
/// `Theme.of(context).extension<AppTokens>()` or `context.tokens`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const new({
    required this.paper,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.line2,
    required this.nucleusCard,
  });

  static const light = AppTokens(
    paper: Color(0xFFFBFAF7),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF14151A),
    muted: Color(0xFF6C6C74),
    line: Color(0x1A14151A),
    line2: Color(0x0F14151A),
    nucleusCard: AppColors.nucleus,
  );

  /// Phase 4, defined now so widgets never hard-code light values.
  static const dark = AppTokens(
    paper: Color(0xFF0B0D0F),
    surface: Color(0xFF15181C),
    ink: Color(0xFFF2F1EC),
    muted: Color(0xFF9A9AA3),
    line: Color(0x1AFFFFFF),
    line2: Color(0x0FFFFFFF),
    nucleusCard: Color(0xFF000000),
  );

  final Color paper;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final Color line2;
  final Color nucleusCard;

  @override
  AppTokens copyWith({
    Color? paper,
    Color? surface,
    Color? ink,
    Color? muted,
    Color? line,
    Color? line2,
    Color? nucleusCard,
  }) {
    return AppTokens(
      paper: paper ?? this.paper,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      nucleusCard: nucleusCard ?? this.nucleusCard,
    );
  }

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      paper: Color.lerp(paper, other.paper, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      nucleusCard: Color.lerp(nucleusCard, other.nucleusCard, t)!,
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
  AppText get text => Theme.of(this).extension<AppText>()!;
}

/// Named text styles (handbook §4.3), coloured for the current brightness.
@immutable
class AppText extends ThemeExtension<AppText> {
  const new({
    required this.display,
    required this.headline,
    required this.title,
    required this.body,
    required this.bodySmall,
    required this.label,
    required this.eyebrow,
  });

  factory of(AppTokens t) {
    const figures = [FontFeature.tabularFigures()];
    return AppText(
      display: TextStyle(
        fontFamily: FontFamilies.display,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.1,
        color: t.ink,
        fontFeatures: figures,
      ),
      headline: TextStyle(
        fontFamily: FontFamilies.display,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: t.ink,
      ),
      title: TextStyle(
        fontFamily: FontFamilies.display,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: t.ink,
      ),
      body: TextStyle(
        fontFamily: FontFamilies.body,
        fontSize: 16,
        height: 1.5,
        color: t.ink,
      ),
      bodySmall: TextStyle(
        fontFamily: FontFamilies.body,
        fontSize: 14,
        height: 1.45,
        color: t.muted,
      ),
      label: TextStyle(
        fontFamily: FontFamilies.body,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: t.ink,
      ),
      eyebrow: TextStyle(
        fontFamily: FontFamilies.mono,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: t.muted,
      ),
    );
  }

  final TextStyle display;
  final TextStyle headline;
  final TextStyle title;
  final TextStyle body;
  final TextStyle bodySmall;
  final TextStyle label;

  /// Uppercase the string yourself; `TextStyle` has no text-transform.
  final TextStyle eyebrow;

  /// Money amounts and dates in lists.
  TextStyle figure(TextStyle base) =>
      base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  @override
  AppText copyWith({
    TextStyle? display,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? body,
    TextStyle? bodySmall,
    TextStyle? label,
    TextStyle? eyebrow,
  }) {
    return AppText(
      display: display ?? this.display,
      headline: headline ?? this.headline,
      title: title ?? this.title,
      body: body ?? this.body,
      bodySmall: bodySmall ?? this.bodySmall,
      label: label ?? this.label,
      eyebrow: eyebrow ?? this.eyebrow,
    );
  }

  @override
  AppText lerp(AppText? other, double t) {
    if (other == null) return this;
    return AppText(
      display: TextStyle.lerp(display, other.display, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      eyebrow: TextStyle.lerp(eyebrow, other.eyebrow, t)!,
    );
  }
}

abstract final class FontFamilies {
  static const display = 'BricolageGrotesque';
  static const body = 'Inter';
  static const mono = 'JetBrainsMono';
}
