import 'package:atompay_mobile/core/forms/form_controller.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:atompay_mobile/features/dashboard/domain/dashboard_controller.dart';
import 'package:atompay_mobile/features/profile/data/photo_service.dart';
import 'package:atompay_mobile/features/profile/data/profile_models.dart';
import 'package:atompay_mobile/features/profile/data/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Always refetched when a profile screen opens: staff decisions change it
/// on the server (handbook rule 8).
final profileProvider = FutureProvider.autoDispose<Profile>(
  (ref) => ref.watch(profileRepositoryProvider).get(),
);

/// Active cities, A–Z. Cached for the session.
final citiesProvider = FutureProvider<List<City>>(
  (ref) => ref.watch(profileRepositoryProvider).cities(),
);

/// Upload progress 0…1 while `POST /profile` is in flight, else null.
final profileUploadProgressProvider =
    NotifierProvider.autoDispose<UploadProgress, double?>(UploadProgress.new);

class UploadProgress extends Notifier<double?> {
  @override
  double? build() => null;

  double? get progress => state;
  set progress(double? value) => state = value;
}

final profileSubmitControllerProvider =
    NotifierProvider.autoDispose<ProfileSubmitController, FormStatus>(
      ProfileSubmitController.new,
    );

class ProfileSubmitController extends FormController {
  /// On success the temp images are deleted and the profile and `/me`
  /// (`kyc_status`) are refetched.
  Future<bool> submit(
    ProfileInput input, {
    required Map<ProfileDocument, String> files,
  }) async {
    final progress = ref.read(profileUploadProgressProvider.notifier);
    final ok = await run(() async {
      progress.progress = 0;
      await ref
          .read(profileRepositoryProvider)
          .submit(
            input,
            files: files,
            onProgress: (p) => progress.progress = p,
          );
    });
    if (!ref.mounted) return ok;
    progress.progress = null;
    if (ok) {
      await ref.read(photoServiceProvider).discard(files.values);
      ref
        ..invalidate(profileProvider)
        ..invalidate(dashboardProvider);
      await ref.read(authControllerProvider.notifier).refreshUser();
    }
    return ok;
  }
}
