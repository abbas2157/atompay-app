import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App version and a human device name, loaded once at launch.
@immutable
class DeviceInfo {
  const new({
    required this.appVersion,
    required this.deviceName,
    required this.platform,
  });

  /// `1.0.0` (no build number), compared against `/app-config.min_version`.
  final String appVersion;

  /// Shown in the signed-in devices list, e.g. `Pixel 7 · Android 14`.
  final String deviceName;

  /// `android` or `ios`, as the API spells it.
  final String platform;
}

/// Overridden in `main()` with the loaded value, and in tests.
final deviceInfoProvider = Provider<DeviceInfo>(
  (ref) => throw UnimplementedError('deviceInfoProvider is set in main()'),
);

Future<DeviceInfo> loadDeviceInfo() async {
  final package = await PackageInfo.fromPlatform();
  final plugin = DeviceInfoPlugin();
  var name = 'Unknown device';
  var platform = 'android';
  try {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final a = await plugin.androidInfo;
        name = '${a.model} · Android ${a.version.release}';
      case TargetPlatform.iOS:
        platform = 'ios';
        final i = await plugin.iosInfo;
        name = '${i.modelName} · iOS ${i.systemVersion}';
      case _:
        break;
    }
  } on Object {
    // Device name is cosmetic; never block launch on it.
  }
  return DeviceInfo(
    appVersion: package.version,
    deviceName: name.length > 100 ? name.substring(0, 100) : name,
    platform: platform,
  );
}
