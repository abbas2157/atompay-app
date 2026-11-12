import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/format/pk.dart';
import 'package:atompay_mobile/core/forms/form_controller.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/features/application/data/application_models.dart';
import 'package:atompay_mobile/features/application/data/application_repository.dart';
import 'package:atompay_mobile/features/application/data/capture_doc.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/launch/data/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---- reads ---------------------------------------------------------------

final profileProvider = FutureProvider<Profile>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(applicationRepositoryProvider).profile();
});

final applicationInfoProvider = FutureProvider<ApplicationInfo>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(applicationRepositoryProvider).application();
});

final applicationHistoryProvider = FutureProvider<List<Assessment>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(applicationRepositoryProvider).history();
});

/// One identity photo, in memory, dropped as soon as nobody shows it.
final documentProvider = FutureProvider.autoDispose
    .family<Uint8List?, CaptureDoc>(
      (ref, doc) => ref.watch(applicationRepositoryProvider).document(doc),
    );

/// `POST /estimate` for an income. Labelled as an estimate on screen.
final estimateProvider = FutureProvider.autoDispose.family<Estimate, int>(
  (ref, income) => ref.watch(applicationRepositoryProvider).estimate(income),
);

// ---- the draft -------------------------------------------------------------

/// Field names are the API's, so 422 errors land on the right field.
abstract final class ApplyFields {
  static const step1 = {
    'full_name',
    'cnic',
    'mobile',
    'date_of_birth',
    'city_id',
    'area_id',
    'residential_address',
  };
  static const step2 = {'cnic_front', 'cnic_back', 'selfie'};
  static const step3 = {
    'employment_status',
    'employer_name',
    'income_source',
    'monthly_income',
    'existing_instalments',
    'monthly_expenses',
  };

  static int stepOf(String field) => step1.contains(field)
      ? 1
      : step2.contains(field)
      ? 2
      : 3;
}

/// Everything the four steps collect. Kept while the customer moves
/// between steps; photos live only in memory.
@immutable
class ApplyDraft {
  const new({
    this.loaded = false,
    this.profile,
    this.info,
    this.fullName = '',
    this.cnic = '',
    this.mobile = '',
    this.dateOfBirth,
    this.city,
    this.area,
    this.address = '',
    this.photos = const {},
    this.employment,
    this.employer = '',
    this.source,
    this.income,
    this.existing,
    this.expenses,
    this.errors = const {},
    this.dirty = false,
  });

  final bool loaded;
  final Profile? profile;
  final ApplicationInfo? info;

  final String fullName;
  final String cnic;
  final String mobile;
  final DateTime? dateOfBirth;
  final Place? city;
  final Place? area;
  final String address;
  final Map<CaptureDoc, Uint8List> photos;

  final String? employment;
  final String employer;
  final String? source;
  final int? income;
  final int? existing;
  final int? expenses;

  /// Field errors, client or server, by API field name.
  final Map<String, String> errors;

  /// The customer changed something since the wizard opened.
  final bool dirty;

  /// A limit is in force: submitting is a limit review.
  bool get isReview => info?.active != null;

  /// On file, or taken in this session.
  bool hasPhoto(CaptureDoc d) =>
      photos.containsKey(d) || (profile?.uploaded(d.key) ?? false);

  /// Name, CNIC, date of birth, address or a photo differ from the
  /// profile on file: the profile goes back to pending.
  bool get identityChanged {
    final p = profile;
    if (p == null || !p.submitted) return true;
    return photos.isNotEmpty ||
        fullName.trim() != (p.fullName ?? '') ||
        Pk.digits(cnic) != Pk.digits(p.cnic ?? '') ||
        (dateOfBirth == null ? null : apiDate(dateOfBirth!)) != p.dateOfBirth ||
        address.trim() != (p.residentialAddress ?? '');
  }

  bool get profileChanged {
    final p = profile;
    if (identityChanged) return true;
    return Pk.normaliseMobile(mobile) != Pk.normaliseMobile(p!.mobile ?? '') ||
        city?.id != p.city?.id ||
        area?.id != p.area?.id;
  }

  ApplyDraft copyWith({
    bool? loaded,
    Profile? profile,
    ApplicationInfo? info,
    String? fullName,
    String? cnic,
    String? mobile,
    DateTime? dateOfBirth,
    Place? city,
    Place? area,
    bool clearArea = false,
    String? address,
    Map<CaptureDoc, Uint8List>? photos,
    String? employment,
    String? employer,
    String? source,
    int? income,
    bool clearIncome = false,
    int? existing,
    bool clearExisting = false,
    int? expenses,
    bool clearExpenses = false,
    Map<String, String>? errors,
    bool? dirty,
  }) => ApplyDraft(
    loaded: loaded ?? this.loaded,
    profile: profile ?? this.profile,
    info: info ?? this.info,
    fullName: fullName ?? this.fullName,
    cnic: cnic ?? this.cnic,
    mobile: mobile ?? this.mobile,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    city: city ?? this.city,
    area: clearArea ? null : (area ?? this.area),
    address: address ?? this.address,
    photos: photos ?? this.photos,
    employment: employment ?? this.employment,
    employer: employer ?? this.employer,
    source: source ?? this.source,
    income: clearIncome ? null : (income ?? this.income),
    existing: clearExisting ? null : (existing ?? this.existing),
    expenses: clearExpenses ? null : (expenses ?? this.expenses),
    errors: errors ?? this.errors,
    dirty: dirty ?? this.dirty,
  );
}

class ApplyFlow extends Notifier<ApplyDraft> {
  @override
  ApplyDraft build() {
    // A new customer starts a new draft.
    ref.watch(sessionUserIdProvider);
    return const ApplyDraft();
  }

  ApplicationRepository get _repo => ref.read(applicationRepositoryProvider);

  /// Pre-fills from the profile and the latest application, once.
  Future<void> load() async {
    if (state.loaded) return;
    final (profile, info) = await (
      ref.read(profileProvider.future),
      ref.read(applicationInfoProvider.future),
    ).wait;
    final latest = info.latest;
    state = ApplyDraft(
      loaded: true,
      profile: profile,
      info: info,
      fullName: profile.fullName ?? '',
      cnic: Pk.formatCnic(profile.cnic ?? ''),
      mobile: Pk.formatMobile(profile.mobile ?? ''),
      dateOfBirth: parseApiDate(profile.dateOfBirth),
      city: profile.city,
      area: profile.area,
      address: profile.residentialAddress ?? '',
      employment: latest?.employmentStatus,
      employer: latest?.employerName ?? '',
      source: latest?.incomeSource,
      income: latest?.monthlyIncome,
      existing: latest?.existingInstalments,
      expenses: latest?.monthlyExpenses,
    );
  }

  void update(ApplyDraft Function(ApplyDraft d) change, {String? field}) {
    final next = change(state);
    state = next.copyWith(
      dirty: true,
      errors: field == null ? null : ({...next.errors}..remove(field)),
    );
  }

  /// A new city clears the area (brief §6).
  void setCity(Place city) {
    if (city.id == state.city?.id) return;
    update((d) => d.copyWith(city: city, clearArea: true), field: 'city_id');
  }

  void setPhoto(CaptureDoc doc, Uint8List bytes) => update(
    (d) => d.copyWith(photos: {...d.photos, doc: bytes}),
    field: doc.key,
  );

  /// The server refused these photos ("This file can't be accepted…"):
  /// forget the bytes so the customer retakes them instead of sending the
  /// same file again. A copy already on file is untouched.
  void dropPhotos(Iterable<String> fields) {
    final refused = fields.map(CaptureDoc.parse).nonNulls.toSet();
    if (!state.photos.keys.any(refused.contains)) return;
    state = state.copyWith(
      photos: {
        for (final e in state.photos.entries)
          if (!refused.contains(e.key)) e.key: e.value,
      },
    );
  }

  void setErrors(Map<String, String> errors) =>
      state = state.copyWith(errors: errors);

  /// Client checks for one step, mirroring the server's rules. Returns
  /// the errors, also stored on the draft.
  Map<String, String> check(int step, {required bool cityHasAreas}) {
    final d = state;
    final e = <String, String>{};
    if (step == 1) {
      if (d.fullName.trim().isEmpty) {
        e['full_name'] = 'Enter your name as it is on your CNIC.';
      }
      if (!Pk.isCnic(d.cnic)) {
        e['cnic'] = 'Enter the 13 digits of your CNIC.';
      }
      if (!Pk.isMobile(d.mobile)) {
        e['mobile'] = 'Enter a mobile number like 0300 1234567.';
      }
      if (d.dateOfBirth == null) {
        e['date_of_birth'] = 'Choose your date of birth.';
      } else if (!Pk.isAdult(d.dateOfBirth!)) {
        e['date_of_birth'] = 'You need to be 18 or older to apply.';
      }
      if (d.city == null) e['city_id'] = 'Choose your city.';
      if (d.city != null && cityHasAreas && d.area == null) {
        e['area_id'] = 'Choose your area.';
      }
      if (d.address.trim().isEmpty) {
        e['residential_address'] = 'Enter your home address.';
      }
    } else if (step == 2) {
      for (final doc in CaptureDoc.values) {
        if (!d.hasPhoto(doc)) {
          e[doc.key] = switch (doc) {
            CaptureDoc.cnicFront => 'Take a photo of the front of your CNIC.',
            CaptureDoc.cnicBack => 'Take a photo of the back of your CNIC.',
            CaptureDoc.selfie => 'Take a selfie holding your CNIC.',
          };
        }
      }
    } else if (step == 3) {
      if (d.employment == null) {
        e['employment_status'] = 'Choose your employment status.';
      }
      if (d.source == null) e['income_source'] = 'Choose your income source.';
      final income = d.income;
      if (income == null || income < 1000) {
        e['monthly_income'] = 'Enter your monthly income in rupees.';
      } else if (income > 100000000) {
        e['monthly_income'] = 'Enter a monthly income up to Rs. 100,000,000.';
      }
    }
    final keep = {
      for (final x in state.errors.entries)
        if (ApplyFields.stepOf(x.key) != step) x.key: x.value,
    };
    state = state.copyWith(errors: {...keep, ...e});
    return e;
  }

  ProfileInput profileInput() {
    final d = state;
    return ProfileInput(
      fullName: d.fullName,
      cnic: Pk.digits(d.cnic),
      mobile: Pk.normaliseMobile(d.mobile) ?? Pk.digits(d.mobile),
      dateOfBirth: apiDate(d.dateOfBirth!),
      residentialAddress: d.address,
      cityId: d.city?.id,
      areaId: d.area?.id,
    );
  }

  IncomeInput incomeInput() {
    final d = state;
    return IncomeInput(
      employmentStatus: d.employment!,
      employerName: d.employer.trim().isEmpty ? null : d.employer,
      incomeSource: d.source!,
      monthlyIncome: d.income!,
      existingInstalments: d.existing ?? 0,
      monthlyExpenses: d.expenses ?? 0,
    );
  }

  /// After a successful send: forget everything, photos first.
  void clear() => state = const ApplyDraft();

  Future<void> saveProfileIfChanged() async {
    if (!state.profileChanged) return;
    final saved = await _repo.saveProfile(profileInput(), photos: state.photos);
    state = state.copyWith(profile: saved, photos: const {});
  }
}

final applyFlowProvider = NotifierProvider<ApplyFlow, ApplyDraft>(
  ApplyFlow.new,
);

/// Where the review step sends the customer after Submit.
enum SubmitOutcome { sent, fixStep1, fixStep2, fixStep3, failed }

/// Step 4: profile first (when changed), then the application.
class SubmitApplicationForm extends FormController {
  Future<SubmitOutcome> submit() async {
    final flow = ref.read(applyFlowProvider.notifier);
    final ok = await run(() async {
      await flow.saveProfileIfChanged();
      return await ref
          .read(applicationRepositoryProvider)
          .apply(flow.incomeInput());
    });
    if (ok == null) {
      final error = state.error;
      // CheckUnavailable (the server couldn't scan a photo just now) falls
      // through to `failed`: everything stays as it is, and the button
      // offers Try again.
      if (error is Validation) {
        flow
          ..dropPhotos(error.fieldErrors.keys)
          ..setErrors({
            for (final e in error.fieldErrors.entries)
              if (e.value.isNotEmpty) e.key: e.value.first,
          });
        final steps = error.fieldErrors.keys.map(ApplyFields.stepOf);
        if (steps.isEmpty) return SubmitOutcome.failed;
        return switch (steps.reduce((a, b) => a < b ? a : b)) {
          1 => SubmitOutcome.fixStep1,
          2 => SubmitOutcome.fixStep2,
          _ => SubmitOutcome.fixStep3,
        };
      }
      return SubmitOutcome.failed;
    }
    ref
      ..invalidate(profileProvider)
      ..invalidate(applicationInfoProvider)
      ..invalidate(applicationHistoryProvider)
      ..invalidate(dashboardProvider);
    await ref.read(sessionProvider.notifier).refreshUser();
    flow.clear();
    return SubmitOutcome.sent;
  }
}

final submitApplicationProvider =
    NotifierProvider.autoDispose<SubmitApplicationForm, FormStatus>(
      SubmitApplicationForm.new,
    );
