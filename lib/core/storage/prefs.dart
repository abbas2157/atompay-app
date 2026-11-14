import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main()'),
);

/// Non-PII flags only. The token and user live in secure storage.
class AppPrefs {
  new(this._prefs);

  final SharedPreferences _prefs;

  static const _consent = 'consent.accepted_v1';
  static const _onboarded = 'onboarding.done_v1';
  static const _voiceExplained = 'askatom.voice_explained';
  static const _notifAsked = 'perm.notifications_explained';
  static const _cameraAsked = 'perm.camera_explained';

  /// First run (disclosures) accepted. Shown once, before sign in.
  bool get consented => _prefs.getBool(_consent) ?? false;
  Future<void> setConsented() => _prefs.setBool(_consent, true);

  /// The intro slides were seen (or skipped). Anyone who already accepted
  /// the disclosures, such as an existing install, never sees them.
  bool get onboarded => _prefs.getBool(_onboarded) ?? consented;
  Future<void> setOnboarded() => _prefs.setBool(_onboarded, true);

  /// The Ask Atom voice explainer was shown, so the next mic tap goes
  /// straight to the system prompt.
  bool get voiceExplained => _prefs.getBool(_voiceExplained) ?? false;
  Future<void> setVoiceExplained() => _prefs.setBool(_voiceExplained, true);

  bool get notificationsExplained => _prefs.getBool(_notifAsked) ?? false;
  Future<void> setNotificationsExplained() => _prefs.setBool(_notifAsked, true);

  bool get cameraExplained => _prefs.getBool(_cameraAsked) ?? false;
  Future<void> setCameraExplained() => _prefs.setBool(_cameraAsked, true);
}

final appPrefsProvider = Provider<AppPrefs>(
  (ref) => AppPrefs(ref.watch(sharedPreferencesProvider)),
);
