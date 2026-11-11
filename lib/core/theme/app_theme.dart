import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The one theme. Light only: the canvas has no dark palette.
ThemeData buildAppTheme() {
  const c = AppColors.light;
  final t = AppText.from(c);
  final scheme = ColorScheme.fromSeed(
    seedColor: c.primary,
    primary: c.primary,
    onPrimary: c.white,
    secondary: c.ink,
    surface: c.white,
    onSurface: c.ink,
    error: c.rose,
  );
  final focusBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.input),
    borderSide: BorderSide(color: c.primary),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'PlusJakartaSans',
    scaffoldBackgroundColor: c.surface,
    extensions: [c, t],
    splashFactory: NoSplash.splashFactory,
    highlightColor: c.primarySoft,
    focusColor: c.primarySoft,
    textTheme: TextTheme(
      displayLarge: t.display,
      headlineLarge: t.h1,
      headlineMedium: t.h2,
      titleLarge: t.h4,
      titleMedium: t.body.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: t.body,
      bodyMedium: t.base,
      bodySmall: t.small,
      labelLarge: t.button,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      surfaceTintColor: c.surface,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: t.h4,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.s14,
        vertical: Space.s14,
      ),
      hintStyle: t.body.copyWith(color: c.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input),
        borderSide: BorderSide(color: c.line2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input),
        borderSide: BorderSide(color: c.line2),
      ),
      focusedBorder: focusBorder,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input),
        borderSide: BorderSide(color: c.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input),
        borderSide: BorderSide(color: c.danger, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input),
        borderSide: BorderSide(color: c.line),
      ),
      errorStyle: t.small.copyWith(color: c.rose),
      errorMaxLines: 3,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.primary,
      selectionColor: c.primaryLine,
      selectionHandleColor: c.primary,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.white,
      ),
      side: BorderSide(color: c.line3, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.line3,
      ),
      thumbColor: WidgetStatePropertyAll(c.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.white,
      surfaceTintColor: c.white,
      modalBarrierColor: c.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.white,
      surfaceTintColor: c.white,
      barrierColor: c.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: t.base.copyWith(
        color: c.white,
        fontWeight: FontWeight.w700,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.input),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        // Predictive back on Android 14+.
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
