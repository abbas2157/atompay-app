import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden images use the real type and icons, not the test font's boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final jakarta = FontLoader('PlusJakartaSans');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    jakarta.addFont(_bytes('assets/fonts/PlusJakartaSans-$w.ttf'));
  }
  await jakarta.load();

  final icons = _materialIcons();
  if (icons != null) {
    await (FontLoader('MaterialIcons')..addFont(_bytes(icons.path))).load();
  }

  await testMain();
}

Future<ByteData> _bytes(String path) async =>
    ByteData.sublistView(await File(path).readAsBytes());

/// The SDK's own copy: `<flutter>/bin/cache/artifacts/material_fonts`.
File? _materialIcons() {
  final roots = <String>[
    ?Platform.environment['FLUTTER_ROOT'],
    // flutter_tester lives in <flutter>/bin/cache/artifacts/engine/<os>/.
    File(Platform.resolvedExecutable)
        .parent
        .parent
        .parent
        .parent
        .parent
        .parent
        .path,
  ];
  for (final root in roots) {
    final f = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (f.existsSync()) return f;
  }
  return null;
}
