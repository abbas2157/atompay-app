import 'package:atompay_mobile/core/config/device.dart';
import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/utils/versions.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:atompay_mobile/features/launch/data/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
sealed class LaunchState {
  const new();
}

final class Launching extends LaunchState {
  const new();
}

final class UpdateRequired extends LaunchState {
  const new(this.storeUrl);

  final String? storeUrl;
}

final class Launched extends LaunchState {
  const new();
}

final launchControllerProvider =
    NotifierProvider<LaunchController, LaunchState>(LaunchController.new);

/// The `/app-config` from launch, kept in memory for the session (handbook
/// §5.2). Defaults when launch was offline.
final appConfigProvider = NotifierProvider<AppConfigHolder, AppConfig>(
  AppConfigHolder.new,
);

class AppConfigHolder extends Notifier<AppConfig> {
  @override
  AppConfig build() => const AppConfig();

  AppConfig get config => state;
  set config(AppConfig value) => state = value;
}

/// `GET /app-config` → force-update gate → restore the session.
class LaunchController extends Notifier<LaunchState> {
  @override
  LaunchState build() => const Launching();

  Future<void> start() async {
    state = const Launching();
    final device = ref.read(deviceInfoProvider);

    try {
      final data = await ref.read(apiClientProvider).get('/app-config');
      final config = AppConfig.fromJson((data as Map).cast<String, dynamic>());
      ref.read(appConfigProvider.notifier).config = config;

      final ios = device.platform == 'ios';
      final minimum = ios ? config.minVersion.ios : config.minVersion.android;
      if (isBelowMinVersion(device.appVersion, minimum)) {
        state = UpdateRequired(
          ios ? config.storeUrl.ios : config.storeUrl.android,
        );
        return;
      }
    } on ApiException {
      // Offline or server trouble: carry on with defaults (handbook §3.5).
    } on Object catch (e, s) {
      // A malformed config must never brick the app.
      debugPrint('app-config ignored: ${e.runtimeType}');
      debugPrintStack(stackTrace: s, maxFrames: 3);
    }

    await ref.read(authControllerProvider.notifier).restore();
    state = const Launched();
  }
}
