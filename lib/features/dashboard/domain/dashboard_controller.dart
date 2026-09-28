import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:atompay_mobile/features/dashboard/data/dashboard_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `GET /dashboard`. Invalidate after anything that changes the customer's
/// state (profile or application submitted, app resumed, pull to refresh).
/// Kept alive so switching tabs doesn't refetch.
final dashboardProvider = FutureProvider<Dashboard>((ref) async {
  // A different (or no) signed-in user starts from scratch, so one
  // customer's dashboard never shows for the next.
  ref.watch(
    authControllerProvider.select((s) => s is SignedIn ? s.user.id : null),
  );
  final data = await ref.watch(apiClientProvider).get('/dashboard');
  return Dashboard.fromJson((data as Map).cast<String, dynamic>());
});
