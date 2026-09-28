import 'package:atompay_mobile/core/config/env.dart';
import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/storage/token_storage.dart';
import 'package:atompay_mobile/core/utils/pk_formatters.dart';
import 'package:atompay_mobile/features/profile/data/profile_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  ),
);

/// KYC section 1 and cities (handbook §8.9).
class ProfileRepository {
  new(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<Profile> get() async =>
      Profile.fromJson(_map(await _api.get('/profile')));

  Future<List<City>> cities() async {
    final data = await _api.get('/cities');
    return [for (final c in data as List) City.fromJson(_map(c))];
  }

  /// Multipart. [files] holds only the images that changed; omitted ones are
  /// kept by the server (required on the first submission).
  Future<Profile> submit(
    ProfileInput input, {
    required Map<ProfileDocument, String> files,
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'full_name': input.fullName.trim(),
      'cnic': Pk.normalizeCnic(input.cnic),
      'mobile': Pk.normalizeMobile(input.mobile),
      'date_of_birth': input.dateOfBirth,
      'residential_address': input.residentialAddress.trim(),
      if (input.cityId != null) 'city_id': input.cityId,
      for (final MapEntry(key: doc, value: path) in files.entries)
        doc.apiName: await MultipartFile.fromFile(
          path,
          filename: '${doc.apiName}.jpg',
        ),
    });
    final data = await _api.upload('/profile', form, onProgress: onProgress);
    return Profile.fromJson(_map(data));
  }

  /// Built from our base URL rather than the server's `url`, so it works
  /// against a dev server reached through a different host.
  Uri documentUri(ProfileDocument doc) =>
      Uri.parse('${Env.apiBaseUrl}/profile/documents/${doc.apiName}');

  /// For `Image.network(headers: …)`. Never cached to disk (handbook rule 12).
  Map<String, String> get authHeaders => {
    'Accept': 'image/*',
    if (_tokens.token case final t?) 'Authorization': 'Bearer $t',
  };

  static Map<String, dynamic> _map(Object? data) =>
      (data! as Map).cast<String, dynamic>();
}
