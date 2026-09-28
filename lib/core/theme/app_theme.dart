import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(AppTokens.light, Brightness.light);

  /// Phase 4. Defined so the tokens stay complete.
  static ThemeData get dark => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final text = AppText.of(t);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: brightness == Brightness.light ? AppColors.nucleus : t.ink,
      onPrimary: brightness == Brightness.light ? AppColors.white : t.paper,
      secondary: AppColors.violet,
      onSecondary: AppColors.white,
      error: AppColors.coral,
      onError: AppColors.white,
      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.muted,
      outline: t.line,
      outlineVariant: t.line2,
    );

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.input),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.paper,
      fontFamily: FontFamilies.body,
      extensions: [t, text],
      splashFactory: InkSparkle.splashFactory,
      textTheme: TextTheme(
        displaySmall: text.display,
        headlineSmall: text.headline,
        titleMedium: text.title,
        bodyLarge: text.body,
        bodyMedium: text.body,
        bodySmall: text.bodySmall,
        labelLarge: text.label,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.paper,
        foregroundColor: t.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.title,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: t.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.paper,
        hintStyle: text.body.copyWith(color: t.muted),
        errorStyle: text.bodySmall.copyWith(color: AppColors.coral),
        errorMaxLines: 3,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.x16,
          vertical: Space.x16,
        ),
        border: border(t.line),
        enabledBorder: border(t.line),
        focusedBorder: border(AppColors.violet, 2),
        errorBorder: border(AppColors.coral),
        focusedErrorBorder: border(AppColors.coral, 2),
        disabledBorder: border(t.line2),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.violet,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.violet,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.nucleus,
        contentTextStyle: text.body.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.input),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        titleTextStyle: text.title,
        contentTextStyle: text.body,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        elevation: 0,
        indicatorColor: AppColors.violet.withValues(alpha: 0.12),
        // The default selected icon is near-white on the pale indicator.
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.violet
                : t.ink,
          ),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          text.bodySmall.copyWith(fontWeight: FontWeight.w600, color: t.ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.violet,
          textStyle: text.label,
          minimumSize: const Size(Sizes.minTouch, Sizes.minTouch),
        ),
      ),
    );
  }
}
