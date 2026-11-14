import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:atompay_mobile/features/plans/data/plans_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One order with its full schedule.
final planDetailProvider = FutureProvider.autoDispose.family<Plan, int>((
  ref,
  orderId,
) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(plansRepositoryProvider).plan(orderId);
});

/// The Key Fact Statement of an order.
final kfsProvider = FutureProvider.autoDispose.family<Kfs, int>((ref, orderId) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(plansRepositoryProvider).kfs(orderId);
});

/// How an order reads in a list (canvas "Orders in every status"): badge
/// words, not just colour.
enum OrderBadge {
  awaitingApproval('Awaiting approval'),
  verification('Verification'),
  processing('Processing'),
  delivered('Delivered'),
  repaying('Repaying'),
  late('Late'),
  completed('Completed'),
  cancelled('Cancelled');

  new(this.label);

  final String label;

  static OrderBadge of(Plan p) => switch (p.status) {
    PlanState.pending when p.order.inVerification => verification,
    PlanState.pending => awaitingApproval,
    PlanState.processing when p.order.delivered => delivered,
    PlanState.processing => processing,
    PlanState.late => late,
    PlanState.completed => completed,
    PlanState.cancelled => cancelled,
    PlanState.onTrack => repaying,
  };

  /// Only these open a schedule.
  bool get hasSchedule => this == repaying || this == late;
}
