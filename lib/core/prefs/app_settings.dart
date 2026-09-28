import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` (and tests) with the loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider is set in main()'),
);

/// UI preferences only: never PII or tokens (handbook §3.6).
@immutable
class AppSettings {
  const new({
    this.themeMode = ThemeMode.system,
    this.localeCode,
    this.biometricLock = false,
  });

  final ThemeMode themeMode;

  /// `en`, `ur`, or null to follow the phone.
  final String? localeCode;
  final bool biometricLock;

  Locale? get locale => localeCode == null ? null : Locale(localeCode!);
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends Notifier<AppSettings> {
  static const _themeKey = 'settings.theme';
  static const _localeKey = 'settings.locale';
  static const _biometricKey = 'settings.biometric';

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPrefsProvider);
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == prefs.getString(_themeKey),
        orElse: () => ThemeMode.system,
      ),
      localeCode: prefs.getString(_localeKey),
      biometricLock: prefs.getBool(_biometricKey) ?? false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AppSettings(
      themeMode: mode,
      localeCode: state.localeCode,
      biometricLock: state.biometricLock,
    );
    await _prefs.setString(_themeKey, mode.name);
  }

  /// Null follows the phone's language.
  Future<void> setLocale(String? code) async {
    state = AppSettings(
      themeMode: state.themeMode,
      localeCode: code,
      biometricLock: state.biometricLock,
    );
    if (code == null) {
      await _prefs.remove(_localeKey);
    } else {
      await _prefs.setString(_localeKey, code);
    }
  }

  Future<void> setBiometricLock({required bool enabled}) async {
    state = AppSettings(
      themeMode: state.themeMode,
      localeCode: state.localeCode,
      biometricLock: enabled,
    );
    await _prefs.setBool(_biometricKey, enabled);
  }
}
