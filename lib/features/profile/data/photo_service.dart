import 'dart:io';

import 'package:atompay_mobile/features/profile/data/profile_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final photoServiceProvider = Provider<PhotoService>((ref) => PhotoService());

/// Thrown when a photo is still over the upload limit after resizing.
class PhotoTooLarge implements Exception;

/// Camera / gallery capture, sized for upload (handbook §5.7): longest side
/// 1600 px, JPEG quality 85, at most 4 MB. `image_picker` does the resize and
/// re-encode itself.
class PhotoService {
  final _picker = ImagePicker();

  static const maxBytes = 4 * 1024 * 1024;
  static const _maxSide = 1600.0;

  /// Returns the path of a temp image, or null if the user cancelled.
  /// Delete it with [discard] after upload.
  Future<String?> pick(ProfileDocument doc, {required bool camera}) async {
    final picked = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      preferredCameraDevice: doc == ProfileDocument.selfie
          ? CameraDevice.front
          : CameraDevice.rear,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    if (await File(picked.path).length() > maxBytes) {
      await discard([picked.path]);
      throw PhotoTooLarge();
    }
    return picked.path;
  }

  /// Best-effort delete of temp images (handbook rule 13).
  Future<void> discard(Iterable<String> paths) async {
    for (final p in paths) {
      try {
        await File(p).delete();
      } on FileSystemException {
        // Already gone.
      }
    }
  }
}
