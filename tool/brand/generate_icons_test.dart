// Renders the AtomPay mark (the same geometry as `AtomLogo`) into every
// launcher-icon and launch-image PNG the platforms need.
//
// Run from the project root when the brand mark changes:
//   flutter test tool/brand/generate_icons_test.dart
//
// It lives outside `test/` so `flutter test` doesn't rewrite assets in CI.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _nucleus = Color(0xFF050708);
const _amber = Color(0xFFFAA53A);
const _coral = Color(0xFFF05465);
const _white = Color(0xFFFFFFFF);

/// Paints the mark into a [size]-pixel square.
///
/// The 44-unit logo box is scaled to [box] of the canvas. [square] fills the
/// whole canvas (iOS icons, which the OS rounds itself); [disc] draws the
/// round nucleus (legacy Android icons).
Future<List<int>> _render(
  int size, {
  double box = 1,
  bool square = false,
  bool disc = false,
  bool raw = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final px = size.toDouble();
  if (square) {
    canvas.drawRect(Rect.fromLTWH(0, 0, px, px), Paint()..color = _nucleus);
  }

  final s = px * box / 44;
  final c = Offset(px / 2, px / 2);
  if (disc) {
    canvas.drawCircle(c, 20 * s, Paint()..color = _nucleus);
  }
  for (final (color, degrees) in [(_amber, 28.0), (_coral, -28.0)]) {
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(degrees * math.pi / 180)
      ..drawOval(
        Rect.fromCenter(center: Offset.zero, width: 34 * s, height: 14 * s),
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s
          ..color = color,
      )
      ..restore();
  }

  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: 'BricolageGrotesque',
            fontWeight: FontWeight.w800,
            fontSize: 17 * s,
            height: 1,
          ),
        )
        ..pushStyle(ui.TextStyle(color: _white))
        ..addText('A');
  final a = builder.build()..layout(ui.ParagraphConstraints(width: px));
  canvas.drawParagraph(a, c - Offset(a.maxIntrinsicWidth / 2, a.height / 2));

  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(
    format: raw ? ui.ImageByteFormat.rawRgba : ui.ImageByteFormat.png,
  );
  return bytes!.buffer.asUint8List();
}

Future<List<int>> _renderRaw(int size, {required double box}) =>
    _render(size, box: box, square: true, raw: true);

/// Re-encodes an opaque render as an RGB PNG (no alpha channel): the App
/// Store rejects app icons that carry alpha, even fully opaque alpha.
Future<List<int>> _opaque(int size, {required double box}) async {
  final rgba = await _renderRaw(size, box: box);
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < size; x++) {
      final i = (y * size + x) * 4;
      raw.add([rgba[i], rgba[i + 1], rgba[i + 2]]);
    }
  }
  List<int> chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    return [..._u32(data.length), ...body, ..._u32(_crc32(body))];
  }

  return [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
    ...chunk('IHDR', [..._u32(size), ..._u32(size), 8, 2, 0, 0, 0]),
    ...chunk('IDAT', ZLibCodec().encode(raw.takeBytes())),
    ...chunk('IEND', const []),
  ];
}

List<int> _u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = crc & 1 == 1 ? 0xEDB88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

Future<void> _write(String path, List<int> bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
}

void main() {
  testWidgets('generate brand icons', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('BricolageGrotesque')
        ..addFont(
          File('assets/fonts/BricolageGrotesque-ExtraBold.ttf')
              .readAsBytes()
              .then(ByteData.sublistView),
        );
      await font.load();

      const res = 'android/app/src/main/res';
      const densities = {
        'mdpi': 1.0,
        'hdpi': 1.5,
        'xhdpi': 2.0,
        'xxhdpi': 3.0,
        'xxxhdpi': 4.0,
      };
      for (final MapEntry(key: d, value: scale) in densities.entries) {
        // Legacy/round launcher icon: 48dp, the round mark.
        await _write(
          '$res/mipmap-$d/ic_launcher.png',
          await _render((48 * scale).round(), box: 0.98, disc: true),
        );
        // Adaptive foreground: 108dp canvas, art inside the 66dp safe zone.
        await _write(
          '$res/mipmap-$d/ic_launcher_foreground.png',
          await _render((108 * scale).round(), box: 66 / 108),
        );
        // Pre-Android-12 launch screen: the mark on the dark window.
        await _write(
          '$res/drawable-$d/launch_logo.png',
          await _render((112 * scale).round()),
        );
      }

      // iOS app icons: full-bleed dark square; iOS rounds the corners.
      const ios = 'ios/Runner/Assets.xcassets';
      const icons = {
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
      };
      for (final MapEntry(key: name, value: px) in icons.entries) {
        await _write(
          '$ios/AppIcon.appiconset/$name',
          await _opaque(px, box: 0.78),
        );
      }
      // iOS launch image (112pt), drawn on the storyboard's dark background.
      for (final (suffix, scale) in [('', 1), ('@2x', 2), ('@3x', 3)]) {
        await _write(
          '$ios/LaunchImage.imageset/LaunchImage$suffix.png',
          await _render(112 * scale),
        );
      }
    });
  });
}
