// Fails when a merged Android manifest declares a permission brief §10
// forbids, or one that isn't on the allow-list.
//
//   flutter build apk --release --flavor prod --dart-define=FLAVOR=prod
//   dart run tool/check_manifest.dart
//
// With no arguments it checks every merged manifest under build/app; pass
// paths to check specific files.
// ignore_for_file: avoid_print

import 'dart:io';

import 'manifest_rules.dart';

void main(List<String> args) {
  final files = args.isNotEmpty
      ? args.map(File.new).toList()
      : _mergedManifests();
  if (files.isEmpty) {
    print(
      'No merged manifest found under build/app/intermediates. Build an '
      'APK or bundle first.',
    );
    exit(2);
  }

  var failed = false;
  for (final file in files) {
    final report = ManifestReport(declaredPermissions(file.readAsStringSync()));
    final name = file.path.replaceAll(r'\', '/');
    if (report.ok) {
      print('OK    $name');
      continue;
    }
    failed = true;
    print('FAIL  $name');
    for (final p in report.forbidden) {
      print('      forbidden (brief §10): $p');
    }
    for (final p in report.unknown) {
      print('      not on the allow-list (tool/manifest_rules.dart): $p');
    }
  }
  exit(failed ? 1 : 0);
}

List<File> _mergedManifests() {
  final root = Directory('build/app/intermediates');
  if (!root.existsSync()) return [];
  return root.listSync(recursive: true).whereType<File>().where((f) {
    final p = f.path.replaceAll(r'\', '/');
    return p.endsWith('/AndroidManifest.xml') &&
        (p.contains('/merged_manifest/') || p.contains('/merged_manifests/'));
  }).toList();
}
