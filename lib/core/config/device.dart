import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The device name sent on sign-in ("Pixel 7 · Android 14") and the app's
/// version. No identifiers beyond what the sessions list shows.
class DeviceInfo {
  String? _name;

  Future<String> name() async {
    if (_name != null) return _name!;
    try {
      final info = DeviceInfoPlugin();
      if (!kIsWeb && Platform.isAndroid) {
        final a = await info.androidInfo;
        return _name = '${a.model} · Android ${a.version.release}';
      }
      if (!kIsWeb && Platform.isIOS) {
        final i = await info.iosInfo;
        return _name = '${i.utsname.machine} · iOS ${i.systemVersion}';
      }
    } on Object {
      // Fall through to the generic name.
    }
    return _name = 'AtomPay app';
  }

  String get platform => !kIsWeb && Platform.isIOS ? 'ios' : 'android';
}

final deviceInfoProvider = Provider<DeviceInfo>((ref) => DeviceInfo());

/// Overridden in `main()` once the platform answers.
final packageInfoProvider = Provider<PackageInfo>(
  (ref) => PackageInfo(
    appName: 'AtomPay',
    packageName: 'com.ecommerce.atompay',
    version: '1.0.0',
    buildNumber: '1',
  ),
);

extension VersionLabel on PackageInfo {
  /// "Version 1.0.0 (1)".
  String get label => 'Version $version ($buildNumber)';
}
