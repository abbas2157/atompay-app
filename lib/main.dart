import 'package:atompay_mobile/app.dart';
import 'package:atompay_mobile/core/config/device.dart';
import 'package:atompay_mobile/core/prefs/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final (device, prefs) = (
    await loadDeviceInfo(),
    await SharedPreferences.getInstance(),
  );

  runApp(
    ProviderScope(
      // Screens own their retry buttons; don't hammer a slow network.
      retry: (_, _) => null,
      overrides: [
        deviceInfoProvider.overrideWithValue(device),
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const AtomPayApp(),
    ),
  );
}
