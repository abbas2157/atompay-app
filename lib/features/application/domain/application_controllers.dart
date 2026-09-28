import 'package:atompay_mobile/core/forms/form_controller.dart';
import 'package:atompay_mobile/features/application/data/application_models.dart';
import 'package:atompay_mobile/features/application/data/application_repository.dart';
import 'package:atompay_mobile/features/dashboard/domain/dashboard_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final applicationProvider = FutureProvider.autoDispose<ApplicationOverview>(
  (ref) => ref.watch(applicationRepositoryProvider).overview(),
);

final applicationHistoryProvider = FutureProvider.autoDispose<List<Assessment>>(
  (ref) => ref.watch(applicationRepositoryProvider).history(),
);

/// Picker values. Public and rarely changing: cached for the session.
final formOptionsProvider = FutureProvider<FormOptions>(
  (ref) => ref.watch(applicationRepositoryProvider).options(),
);

final applicationSubmitControllerProvider =
    NotifierProvider.autoDispose<ApplicationSubmitController, FormStatus>(
      ApplicationSubmitController.new,
    );

class ApplicationSubmitController extends FormController {
  /// On success the application and dashboard are refetched.
  Future<bool> submit(ApplicationInput input) async {
    final ok = await run(
      () => ref.read(applicationRepositoryProvider).submit(input),
    );
    if (ok && ref.mounted) {
      ref
        ..invalidate(applicationProvider)
        ..invalidate(applicationHistoryProvider)
        ..invalidate(dashboardProvider);
    }
    return ok;
  }
}

/// The public "What could I get?" estimate (handbook §5.8).
final estimateControllerProvider =
    NotifierProvider.autoDispose<EstimateController, FormStatus>(
      EstimateController.new,
    );

final estimateResultProvider =
    NotifierProvider.autoDispose<EstimateResult, Estimate?>(EstimateResult.new);

class EstimateResult extends Notifier<Estimate?> {
  @override
  Estimate? build() => null;

  Estimate? get value => state;
  set value(Estimate? v) => state = v;
}

class EstimateController extends FormController {
  Future<bool> estimate(int monthlyIncome) {
    ref.read(estimateResultProvider.notifier).value = null;
    return run(() async {
      final estimate = await ref
          .read(applicationRepositoryProvider)
          .estimate(monthlyIncome);
      ref.read(estimateResultProvider.notifier).value = estimate;
    });
  }
}
