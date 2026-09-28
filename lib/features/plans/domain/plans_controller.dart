import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Map<String, dynamic> _map(Object? d) => (d! as Map).cast<String, dynamic>();

/// Orders with repayments running (the Active tab).
final activePlansProvider = FutureProvider.autoDispose<List<Plan>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/plans');
  return [for (final p in data as List) Plan.fromJson(_map(p))];
});

/// Fully repaid orders (the History tab). The endpoint returns active ones
/// too with `include=completed`; the Active tab already shows those.
final completedPlansProvider = FutureProvider.autoDispose<List<Plan>>((
  ref,
) async {
  final data = await ref
      .watch(apiClientProvider)
      .get('/plans', query: {'include': 'completed'});
  return [
    for (final p in data as List)
      if (_map(p)['state'] == 'completed') Plan.fromJson(_map(p)),
  ];
});

/// One plan with its full schedule. `404` if it isn't the customer's.
final planProvider = FutureProvider.autoDispose.family<Plan, int>((
  ref,
  orderId,
) async {
  final data = await ref.watch(apiClientProvider).get('/plans/$orderId');
  return Plan.fromJson(_map(data));
});
