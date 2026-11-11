import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/manifest_rules.dart';

/// Brief §15: release rules that a test can hold the code to.
void main() {
  group('manifest rules (brief §10)', () {
    test('forbidden permissions are caught, removed ones ignored', () {
      const xml = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.READ_CONTACTS"/>
  <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
  <uses-permission-sdk-23 android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
      tools:node="remove"/>
  <uses-permission android:name="com.example.SOMETHING_NEW"/>
</manifest>''';
      final report = ManifestReport(declaredPermissions(xml));
      expect(report.forbidden, {
        'android.permission.READ_CONTACTS',
        'android.permission.READ_MEDIA_IMAGES',
        'android.permission.ACCESS_FINE_LOCATION',
      });
      expect(report.unknown, {'com.example.SOMETHING_NEW'});
      expect(report.ok, isFalse);
    });

    test("the app's own manifest declares only allowed permissions", () {
      final xml = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      final report = ManifestReport(declaredPermissions(xml));
      expect(report.forbidden, isEmpty);
      expect(report.unknown, isEmpty);
      // The camera plugin's storage permission stays stripped.
      expect(
        RegExp(r'WRITE_EXTERNAL_STORAGE"\s+tools:node="remove"').hasMatch(xml),
        isTrue,
      );
    });
  });

  test('iOS purpose strings exist for camera, microphone and speech', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final key in [
      'NSCameraUsageDescription',
      'NSMicrophoneUsageDescription',
      'NSSpeechRecognitionUsageDescription',
    ]) {
      expect(plist, contains('<key>$key</key>'), reason: key);
    }
    // Brief §10: no gallery, contacts or location.
    for (final key in [
      'NSPhotoLibraryUsageDescription',
      'NSContactsUsageDescription',
      'NSLocationWhenInUseUsageDescription',
    ]) {
      expect(plist, isNot(contains(key)), reason: key);
    }
  });

  test('no hard-coded colours or font sizes outside the theme (brief §4)', () {
    final offending = <String>[];
    final colour = RegExp(r'Color\(0x|Colors\.(?!transparent\b)[a-z]');
    final fontSize = RegExp(r'fontSize\s*:');
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) {
          final p = f.path.replaceAll(r'\', '/');
          return p.endsWith('.dart') &&
              !p.endsWith('.g.dart') &&
              !p.endsWith('.freezed.dart') &&
              !p.contains('lib/core/theme/');
        });
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (colour.hasMatch(line) || fontSize.hasMatch(line)) {
          offending.add('${f.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(offending, isEmpty, reason: offending.join('\n'));
  });
}
