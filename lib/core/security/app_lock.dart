import 'package:atompay_mobile/core/prefs/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => BiometricService(LocalAuthentication()),
);

/// Fingerprint / face unlock over the stored session (handbook §3.1). The
/// token itself stays in secure storage; this only gates the UI.
class BiometricService {
  new(this._auth);

  final LocalAuthentication _auth;

  /// True when the phone can do biometrics (or a device PIN fallback).
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() &&
          (await _auth.canCheckBiometrics ||
              (await _auth.getAvailableBiometrics()).isNotEmpty);
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason);
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }
}

/// Whether the signed-in UI is hidden behind the lock screen.
final appLockProvider = NotifierProvider<AppLockController, bool>(
  AppLockController.new,
);

class AppLockController extends Notifier<bool> {
  /// Coming back after this long in the background locks again.
  static const relockAfter = Duration(minutes: 1);

  DateTime? _backgroundedAt;

  /// Locked at launch when the customer turned biometric lock on.
  @override
  bool build() => ref.read(appSettingsProvider).biometricLock;

  void unlock() => state = false;

  void lock() {
    if (ref.read(appSettingsProvider).biometricLock) state = true;
  }

  void backgrounded() => _backgroundedAt = DateTime.now();

  void resumed() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since != null && DateTime.now().difference(since) >= relockAfter) {
      lock();
    }
  }
}
