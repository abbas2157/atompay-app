import 'dart:async';
import 'dart:io' show Platform;

import 'package:atompay_mobile/core/config/device.dart';
import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/storage/prefs.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/launch/data/app_config.dart';
import 'package:atompay_mobile/features/launch/data/config_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'launch_controller.g.dart';

@immutable
class LaunchState {
  const new({
    this.ready = false,
    this.config = const AppConfig(),
    this.updateRequired = false,
    this.maintenance = false,
  });

  /// Config fetched (or failed) and the session restored.
  final bool ready;
  final AppConfig config;
  final bool updateRequired;

  /// The config flag, or a 503 from any call.
  final bool maintenance;

  LaunchState copyWith({
    bool? ready,
    AppConfig? config,
    bool? updateRequired,
    bool? maintenance,
  }) => LaunchState(
    ready: ready ?? this.ready,
    config: config ?? this.config,
    updateRequired: updateRequired ?? this.updateRequired,
    maintenance: maintenance ?? this.maintenance,
  );
}

/// `GET /app-config`, then `GET /me` when a token exists (brief §9).
@Riverpod(keepAlive: true)
class Launch extends _$Launch {
  StreamSubscription<ApiEvent>? _events;

  @override
  LaunchState build() {
    _events = ref
        .watch(apiEventsProvider)
        .stream
        .where((e) => e is MaintenanceDetected)
        .listen((_) => state = state.copyWith(maintenance: true));
    ref.onDispose(() => _events?.cancel());
    return const LaunchState();
  }

  Future<void> start() async {
    await _loadConfig();
    // Restored even behind Update or Maintenance, so the guards know where
    // to go once those clear.
    await ref.read(sessionProvider.notifier).restore();
    state = state.copyWith(ready: true);
  }

  /// Maintenance's Try again: re-runs app-config, and continues if it's
  /// over.
  Future<void> retry() async {
    state = state.copyWith(maintenance: false);
    await _loadConfig();
    if (!state.maintenance && ref.read(sessionProvider) is SessionUnknown) {
      await ref.read(sessionProvider.notifier).restore();
    }
  }

  Future<void> _loadConfig() async {
    try {
      final config = await ref.read(configRepositoryProvider).appConfig();
      state = state.copyWith(
        config: config,
        updateRequired: _isOutdated(config),
        maintenance: config.maintenance.active,
      );
    } on Server catch (e) {
      // 503 is `php artisan down`.
      state = state.copyWith(maintenance: e.isMaintenance);
    } on ApiException {
      // Offline or slow: keep the defaults and carry on.
    }
  }

  bool _isOutdated(AppConfig config) {
    final min = defaultTargetPlatform == TargetPlatform.iOS
        ? config.minVersion.ios
        : config.minVersion.android;
    if (min == null) return false;
    return isBelow(ref.read(packageInfoProvider).version, min);
  }
}

/// Compares `major.minor.patch` only; build and pre-release tags (`-dev`)
/// are ignored.
bool isBelow(String current, String minimum) {
  Version core(String v) {
    final m = RegExp(r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(v.trim());
    if (m == null) return Version.none;
    return Version(
      int.parse(m.group(1)!),
      int.parse(m.group(2) ?? '0'),
      int.parse(m.group(3) ?? '0'),
    );
  }

  return core(current) < core(minimum);
}

/// The config for widgets; defaults until launch has fetched it.
@Riverpod(keepAlive: true)
AppConfig appConfig(Ref ref) => ref.watch(launchProvider).config;

/// First run (disclosures) accepted. Shown once, before sign-in.
@Riverpod(keepAlive: true)
class Consent extends _$Consent {
  @override
  bool build() => ref.watch(appPrefsProvider).consented;

  Future<void> accept() async {
    await ref.read(appPrefsProvider).setConsented();
    state = true;
  }
}

/// The intro slides were seen. Shown once, before First run.
@Riverpod(keepAlive: true)
class Onboarded extends _$Onboarded {
  @override
  bool build() => ref.watch(appPrefsProvider).onboarded;

  Future<void> finish() async {
    await ref.read(appPrefsProvider).setOnboarded();
    state = true;
  }
}

/// Which store this build is installed from.
String get platformKey => !kIsWeb && Platform.isIOS ? 'ios' : 'android';
