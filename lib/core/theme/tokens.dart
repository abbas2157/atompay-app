import 'package:flutter/material.dart';

/// Every colour in the app (brief §4). Widgets read these through
/// `context.colors`; a hex value anywhere else fails the token test.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const new({
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.cam,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.primaryLine,
    required this.body,
    required this.muted,
    required this.onDark,
    required this.onDark2,
    required this.white,
    required this.surface,
    required this.surface2,
    required this.field,
    required this.line,
    required this.line2,
    required this.line3,
    required this.greySoft,
    required this.skel,
    required this.glyph,
    required this.green,
    required this.greenSoft,
    required this.greenLine,
    required this.greenWash,
    required this.greenOnDark,
    required this.amber,
    required this.amberSoft,
    required this.amberInk,
    required this.amberWash,
    required this.rose,
    required this.roseSoft,
    required this.roseLine,
    required this.danger,
    required this.dangerWash,
    required this.apayCoral,
    required this.apayAmber,
    required this.apayWash,
    required this.apayLine,
    required this.scrim,
    required this.shadow,
  });

  static const light = AppColors(
    ink: Color(0xFF14213D),
    ink2: Color(0xFF1C2740),
    ink3: Color(0xFF22305A),
    cam: Color(0xFF0B1220),
    primary: Color(0xFF2747C7),
    primaryDark: Color(0xFF1D3AA6),
    primarySoft: Color(0xFFEEF2FD),
    primaryLine: Color(0xFFCFD9F7),
    body: Color(0xFF4F5B76),
    muted: Color(0xFF656F88),
    onDark: Color(0xFFD7DEEC),
    onDark2: Color(0xFFB9C2D6),
    white: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F7FB),
    surface2: Color(0xFFF8FAFE),
    field: Color(0xFFFBFCFE),
    line: Color(0xFFE3E8F1),
    line2: Color(0xFFDCE2EC),
    line3: Color(0xFFC9D2E3),
    greySoft: Color(0xFFEEF1F6),
    skel: Color(0xFFE9EDF4),
    glyph: Color(0xFFAAB5C8),
    green: Color(0xFF18794A),
    greenSoft: Color(0xFFE8F7EF),
    greenLine: Color(0xFFB7E2C8),
    greenWash: Color(0xFFF3FBF6),
    greenOnDark: Color(0xFF7BE3B9),
    amber: Color(0xFFF7A928),
    amberSoft: Color(0xFFFFF5E0),
    amberInk: Color(0xFF8A5A00),
    amberWash: Color(0xFFFFFBF2),
    rose: Color(0xFFB0283F),
    roseSoft: Color(0xFFFDEEF1),
    roseLine: Color(0xFFF3C9D1),
    danger: Color(0xFFD23C4E),
    dangerWash: Color(0xFFFFF7F8),
    apayCoral: Color(0xFFF05465),
    apayAmber: Color(0xFFFAA53A),
    apayWash: Color(0xFFFFF6EE),
    apayLine: Color(0xFFF6DFD2),
    scrim: Color(0x7314213D),
    shadow: Color(0x2E14213D),
  );

  final Color ink;
  final Color ink2;
  final Color ink3;

  /// Camera background.
  final Color cam;
  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color primaryLine;
  final Color body;
  final Color muted;
  final Color onDark;
  final Color onDark2;
  final Color white;
  final Color surface;
  final Color surface2;
  final Color field;
  final Color line;
  final Color line2;
  final Color line3;
  final Color greySoft;
  final Color skel;
  final Color glyph;
  final Color green;
  final Color greenSoft;
  final Color greenLine;
  final Color greenWash;
  final Color greenOnDark;

  /// Fill only. Amber is never text: use [amberInk].
  final Color amber;
  final Color amberSoft;
  final Color amberInk;
  final Color amberWash;

  /// The only red used for text.
  final Color rose;
  final Color roseSoft;
  final Color roseLine;
  final Color danger;
  final Color dangerWash;

  /// Graphics only, never text.
  final Color apayCoral;
  final Color apayAmber;
  final Color apayWash;
  final Color apayLine;

  /// Behind sheets and dialogs (ink at 45%).
  final Color scrim;
  final Color shadow;

  /// The AtomPay gradient. It fills the limit card and nothing else.
  LinearGradient get apayGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [apayAmber, apayCoral],
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) => this;
}

/// The type scale: these eleven sizes and nothing else (brief §4).
/// The launch screens (native and in-app splash): the "nucleus" behind
/// the mark. Matches `@color/nucleus` on Android and the iOS LaunchScreen.
abstract final class LaunchBrand {
  static const nucleus = Color(0xFF050708);
}

abstract final class FontSizes {
  static const double xs = 11;
  static const double sm = 12;
  static const double md = 13;
  static const double base = 14;
  static const double body = 15;
  static const double h4 = 17;
  static const double h3 = 20;
  static const double h2 = 22;
  static const double h1b = 24;
  static const double h1 = 30;
  static const double display = 38;
}

/// Spacing on the 2/4/6/8 rhythm.
abstract final class Space {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s22 = 22;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  /// Screen side gutter.
  static const double gutter = 16;
}

abstract final class Radii {
  static const double card = 24;
  static const double sheet = 24;
  static const double list = 20;
  static const double productCard = 22;
  static const double row = 16;
  static const double input = 14;
  static const double note = 14;
  static const double tile = 12;
  static const double pill = 999;
}

/// Touch and control sizes.
abstract final class Sizes {
  /// The floor for every target (brief §4).
  static const double target = 48;
  static const double buttonLarge = 54;
  static const double iconTile = 40;
  static const double appBar = 56;
  static const double contentMax = 1040;
  static const double focusRing = 3;
  static const double focusGap = 2;
}

/// Named text styles built from the scale. Colours come from [AppColors].
@immutable
class AppText extends ThemeExtension<AppText> {
  const new({
    required this.display,
    required this.h1,
    required this.h1b,
    required this.h2,
    required this.h3,
    required this.h4,
    required this.lead,
    required this.body,
    required this.base,
    required this.small,
    required this.tiny,
    required this.xs,
    required this.eyebrow,
    required this.label,
    required this.button,
    required this.buttonLarge,
  });

  factory from(AppColors c) {
    const family = 'PlusJakartaSans';
    const tab = [FontFeature.tabularFigures()];
    TextStyle s(
      double size,
      FontWeight weight,
      Color color, {
      double? spacing,
      double? height,
    }) => TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
      height: height,
      fontFeatures: tab,
    );
    return AppText(
      display: s(
        FontSizes.display,
        FontWeight.w800,
        c.ink,
        spacing: -1.3,
        height: 1.1,
      ),
      h1: s(FontSizes.h1, FontWeight.w800, c.ink, spacing: -1, height: 1.08),
      h1b: s(FontSizes.h1b, FontWeight.w800, c.ink, spacing: -0.6, height: 1.1),
      h2: s(FontSizes.h2, FontWeight.w800, c.ink, spacing: -0.5, height: 1.15),
      h3: s(FontSizes.h3, FontWeight.w800, c.ink, spacing: -0.4, height: 1.2),
      h4: s(FontSizes.h4, FontWeight.w800, c.ink, spacing: -0.2, height: 1.25),
      lead: s(FontSizes.body, FontWeight.w500, c.body, height: 1.6),
      body: s(FontSizes.body, FontWeight.w500, c.ink, height: 1.45),
      base: s(FontSizes.base, FontWeight.w600, c.body, height: 1.5),
      small: s(FontSizes.md, FontWeight.w600, c.muted, height: 1.5),
      tiny: s(FontSizes.sm, FontWeight.w600, c.muted, height: 1.4),
      xs: s(FontSizes.xs, FontWeight.w700, c.muted, height: 1.3),
      eyebrow: s(FontSizes.sm, FontWeight.w800, c.primary, spacing: 1.6),
      label: s(FontSizes.base, FontWeight.w600, c.ink),
      button: s(FontSizes.body, FontWeight.w700, c.ink),
      buttonLarge: s(FontSizes.h4, FontWeight.w700, c.ink),
    );
  }

  final TextStyle display;
  final TextStyle h1;
  final TextStyle h1b;
  final TextStyle h2;
  final TextStyle h3;
  final TextStyle h4;
  final TextStyle lead;
  final TextStyle body;
  final TextStyle base;
  final TextStyle small;
  final TextStyle tiny;
  final TextStyle xs;

  /// Upper-case it at the call site: `'Welcome back'.toUpperCase()`.
  final TextStyle eyebrow;
  final TextStyle label;
  final TextStyle button;
  final TextStyle buttonLarge;

  @override
  AppText copyWith() => this;

  @override
  AppText lerp(AppText? other, double t) => this;
}

extension ThemeTokens on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  AppText get text => Theme.of(this).extension<AppText>()!;

  /// True when the user asked the OS for less motion.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
}
