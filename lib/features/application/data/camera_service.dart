import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:atompay_mobile/core/storage/prefs.dart';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where camera permission stands (brief §10: asked on the first capture,
/// after the explainer).
enum CamPermission {
  granted,

  /// Never asked: show the explainer, then the system prompt.
  notAsked,

  /// Refused, but the system will ask again.
  denied,

  /// Only Settings can turn it back on.
  blocked,
}

/// The largest photo the server takes (`docs/api/profile.md`).
const maxPhotoBytes = 4 * 1024 * 1024;

class PhotoTooLarge implements Exception {
  const new();
}

class NoCamera implements Exception {
  const new();
}

/// A live camera. Widgets never touch the plugin directly, so tests can
/// swap in a fake.
abstract class CameraSession {
  Widget preview();
  bool get hasFlash;
  Future<void> setFlash({required bool on});

  /// Takes a JPEG into memory. The plugin's temporary file is deleted at
  /// once: identity photos are never left on the phone.
  ///
  /// Always JPEG: the server refuses HEIC, which is what iPhones shoot.
  Future<Uint8List> take();
  Future<void> dispose();
}

abstract class CameraService {
  Future<CamPermission> status();

  /// Shows the system prompt.
  Future<CamPermission> request();
  Future<void> openSettings();

  /// The back camera for the CNIC, the front one for the selfie.
  Future<CameraSession> open({required bool front});
}

final cameraServiceProvider = Provider<CameraService>(
  (ref) => PluginCameraService(ref.watch(sharedPreferencesProvider)),
);

class PluginCameraService implements CameraService {
  new(this._prefs);

  final SharedPreferences _prefs;
  static const _askedKey = 'camera.asked';

  @override
  Future<CamPermission> status() async {
    final s = await Permission.camera.status;
    if (s.isGranted || s.isLimited) return CamPermission.granted;
    if (s.isPermanentlyDenied || s.isRestricted) return CamPermission.blocked;
    return (_prefs.getBool(_askedKey) ?? false)
        ? CamPermission.denied
        : CamPermission.notAsked;
  }

  @override
  Future<CamPermission> request() async {
    await _prefs.setBool(_askedKey, true);
    final s = await Permission.camera.request();
    if (s.isGranted || s.isLimited) return CamPermission.granted;
    if (s.isPermanentlyDenied || s.isRestricted) return CamPermission.blocked;
    return CamPermission.denied;
  }

  @override
  Future<void> openSettings() => openAppSettings();

  @override
  Future<CameraSession> open({required bool front}) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw const NoCamera();
    final want = front ? CameraLensDirection.front : CameraLensDirection.back;
    final description = cameras.firstWhere(
      (c) => c.lensDirection == want,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      description,
      // 1080p: sharp enough to read a CNIC, well under 4 MB as JPEG.
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    await controller.setFlashMode(FlashMode.off);
    return _PluginSession(controller, hasFlash: !front);
  }
}

class _PluginSession implements CameraSession {
  new(this._c, {required this.hasFlash});

  final CameraController _c;

  @override
  final bool hasFlash;

  @override
  Widget preview() => CameraPreview(_c);

  @override
  Future<void> setFlash({required bool on}) =>
      _c.setFlashMode(on ? FlashMode.always : FlashMode.off);

  @override
  Future<Uint8List> take() async {
    final file = await _c.takePicture();
    try {
      final bytes = await compressPhoto(await file.readAsBytes());
      if (bytes.length > maxPhotoBytes) throw const PhotoTooLarge();
      return bytes;
    } finally {
      unawaited(_delete(file.path));
    }
  }

  static Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  @override
  Future<void> dispose() => _c.dispose();
}

/// Re-encodes a camera photo as JPEG at quality 85 (`docs/api/profile.md`):
/// the server refuses HEIC, and an iPhone can hand back HEIC whatever the
/// camera was asked for. The camera already shoots 1080p, which the
/// plugin's default 1920 × 1080 floor leaves unscaled. EXIF (location,
/// device) is dropped after the photo is turned upright.
Future<Uint8List> compressPhoto(Uint8List bytes) =>
    FlutterImageCompress.compressWithList(
      bytes,
      quality: 85,
      // The default, said out loud: JPEG is the whole point.
      // ignore: avoid_redundant_argument_values
      format: CompressFormat.jpeg,
    );
