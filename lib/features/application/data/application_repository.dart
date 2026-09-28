import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/features/application/data/application_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final applicationRepositoryProvider = Provider<ApplicationRepository>(
  (ref) => ApplicationRepository(ref.watch(apiClientProvider)),
);

/// KYC section 3 (income), form options and the public estimate.
class ApplicationRepository {
  new(this._api);

  final ApiClient _api;

  Future<ApplicationOverview> overview() async =>
      ApplicationOverview.fromJson(_map(await _api.get('/application')));

  /// `201` → the new pending assessment. `409 profile_required` when no
  /// identity profile has been submitted.
  Future<Assessment> submit(ApplicationInput input) async =>
      Assessment.fromJson(
        _map(await _api.post('/application', data: input.toJson())),
      );

  /// Newest first.
  Future<List<Assessment>> history() async {
    final data = await _api.get('/application/history');
    return [for (final a in data as List) Assessment.fromJson(_map(a))];
  }

  Future<FormOptions> options() async =>
      FormOptions.fromJson(_map(await _api.get('/options')));

  Future<Estimate> estimate(int monthlyIncome) async => Estimate.fromJson(
    _map(await _api.post('/estimate', data: {'monthly_income': monthlyIncome})),
  );

  static Map<String, dynamic> _map(Object? data) =>
      (data! as Map).cast<String, dynamic>();
}
