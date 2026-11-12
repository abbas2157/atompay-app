import 'dart:typed_data';

import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/features/application/data/application_models.dart';
import 'package:atompay_mobile/features/application/data/capture_doc.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'application_repository.g.dart';

/// What `POST /profile` sends besides the photos. Every text field, every
/// time.
class ProfileInput {
  const new({
    required this.fullName,
    required this.cnic,
    required this.mobile,
    required this.dateOfBirth,
    required this.residentialAddress,
    this.cityId,
    this.areaId,
  });

  final String fullName;
  final String cnic;
  final String mobile;

  /// `YYYY-MM-DD`.
  final String dateOfBirth;
  final String residentialAddress;
  final int? cityId;
  final int? areaId;
}

/// What `POST /application` sends.
class IncomeInput {
  const new({
    required this.employmentStatus,
    required this.incomeSource,
    required this.monthlyIncome,
    this.employerName,
    this.existingInstalments = 0,
    this.monthlyExpenses = 0,
  });

  final String employmentStatus;
  final String? employerName;
  final String incomeSource;
  final int monthlyIncome;
  final int existingInstalments;
  final int monthlyExpenses;
}

/// Profile (KYC section 1) and application (KYC section 3).
class ApplicationRepository {
  new(this._dio);

  final Dio _dio;

  Future<Profile> profile() => guard(() async {
    final r = await _dio.get<dynamic>('/profile');
    return Profile.fromJson(dataOf(r));
  });

  /// Multipart. Photos are sent from memory and never touch the disk;
  /// omit one to keep the copy on file.
  ///
  /// Throws [CheckUnavailable] when the server couldn't scan a photo just
  /// now (see [scanErrors]).
  Future<Profile> saveProfile(
    ProfileInput input, {
    Map<CaptureDoc, Uint8List> photos = const {},
  }) async {
    try {
      return await _saveProfile(input, photos);
    } on Validation catch (e) {
      throw scanErrors(e);
    }
  }

  Future<Profile> _saveProfile(
    ProfileInput input,
    Map<CaptureDoc, Uint8List> photos,
  ) => guard(() async {
    final form = FormData.fromMap({
      'full_name': input.fullName.trim(),
      'cnic': input.cnic,
      'mobile': input.mobile,
      'date_of_birth': input.dateOfBirth,
      'residential_address': input.residentialAddress.trim(),
      if (input.cityId != null) 'city_id': input.cityId,
      if (input.areaId != null) 'area_id': input.areaId,
      for (final e in photos.entries)
        e.key.key: MultipartFile.fromBytes(
          e.value,
          filename: '${e.key.key}.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
    });
    final r = await _dio.post<dynamic>(
      '/profile',
      data: form,
      // The server virus-scans each photo before answering, so allow well
      // over the 60 s the contract asks for, both ways.
      options: Options(
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
    return Profile.fromJson(dataOf(r));
  });

  /// The customer's own photo, into memory only (`no-store`): identity
  /// documents are never cached. Null when it hasn't been uploaded.
  Future<Uint8List?> document(CaptureDoc doc) async {
    try {
      return await guard(() async {
        final r = await _dio.get<List<int>>(
          '/profile/documents/${doc.key}',
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'Cache-Control': 'no-store'},
          ),
        );
        final data = r.data;
        return data == null ? null : Uint8List.fromList(data);
      });
    } on NotFound {
      return null;
    }
  }

  Future<ApplicationInfo> application() => guard(() async {
    final r = await _dio.get<dynamic>('/application');
    return ApplicationInfo.fromJson(dataOf(r));
  });

  /// 201 with the new pending assessment. 409 `profile_required` or
  /// `nothing_changed`.
  Future<Assessment> apply(IncomeInput input) => guard(() async {
    final r = await _dio.post<dynamic>(
      '/application',
      data: {
        'employment_status': input.employmentStatus,
        if (input.employerName != null && input.employerName!.isNotEmpty)
          'employer_name': input.employerName!.trim(),
        'income_source': input.incomeSource,
        'monthly_income': input.monthlyIncome,
        'existing_instalments': input.existingInstalments,
        'monthly_expenses': input.monthlyExpenses,
      },
    );
    return Assessment.fromJson(dataOf(r));
  });

  /// Newest first.
  Future<List<Assessment>> history() => guard(() async {
    final r = await _dio.get<dynamic>('/application/history');
    return listOf(r).map(Assessment.fromJson).toList();
  });

  /// Public. A preview from income alone; nothing is saved.
  Future<Estimate> estimate(int monthlyIncome) => guard(() async {
    final r = await _dio.post<dynamic>(
      '/estimate',
      data: {'monthly_income': monthlyIncome},
    );
    return Estimate.fromJson(dataOf(r));
  });
}

/// Sorts the photo errors of a `POST /profile` 422 (`docs/api/profile.md`).
/// The server scans each photo and answers on `cnic_front`, `cnic_back`
/// or `selfie` with one of:
///
/// - "This file can't be accepted…": the photo was refused. It stays a
///   field error, shown under that photo, and the customer retakes it.
/// - "We couldn't check this file just now…": the scanner was down.
///   Nothing is wrong with the photo, so it's no field error at all: when
///   it's the only problem this returns [CheckUnavailable]; next to real
///   field errors it's dropped, and the resubmit after fixing them scans
///   again.
///
/// This is the one place that reads these messages; screens switch on the
/// type.
ApiException scanErrors(Validation error) {
  String? unavailable;
  final rest = <String, List<String>>{};
  for (final MapEntry(:key, :value) in error.fieldErrors.entries) {
    final kept = CaptureDoc.parse(key) == null
        ? value
        : [
            for (final m in value)
              if (!_isScanUnavailable(m)) m,
          ];
    if (kept.length < value.length) {
      unavailable ??= value.firstWhere(_isScanUnavailable);
    }
    if (kept.isNotEmpty) rest[key] = kept;
  }
  if (unavailable == null) return error;
  if (rest.isEmpty) return CheckUnavailable(unavailable);
  return Validation(error.message, fieldErrors: rest);
}

bool _isScanUnavailable(String message) => message
    .replaceAll('\u2019', "'") // a curly apostrophe counts too
    .toLowerCase()
    .startsWith("we couldn't check this file");

@Riverpod(keepAlive: true)
ApplicationRepository applicationRepository(Ref ref) =>
    ApplicationRepository(ref.watch(dioProvider));
