import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/storage/response_cache.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'plans_repository.g.dart';

/// The customer's orders and their plans (`docs/api/plans.md`).
class PlansRepository {
  new(this._dio, this._cache);

  final Dio _dio;
  final ResponseCache _cache;

  /// Every order, newest first; the last copy when offline.
  Future<Cached<List<Plan>>> plans() => _cache.fetch(
    key: 'plans',
    load: () => guard(() async => (await _dio.get<dynamic>('/plans')).data),
    parse: (body) => listIn(body).map(Plan.fromJson).toList(),
  );

  /// 404 when the order isn't the customer's.
  Future<Kfs> kfs(int orderId) => guard(() async {
    final r = await _dio.get<dynamic>('/plans/$orderId/kfs');
    return Kfs.fromJson(dataOf(r));
  });

  /// `channel`: `email` or `sms`. 202 when queued.
  Future<void> sendKfs(int orderId, String channel) => guard(() async {
    await _dio.post<dynamic>(
      '/plans/$orderId/kfs/send',
      data: {'channel': channel},
    );
  });

  /// One order with its full schedule. 404 when it isn't the customer's.
  Future<Plan> plan(int orderId) => guard(() async {
    final r = await _dio.get<dynamic>('/plans/$orderId');
    return Plan.fromJson(dataOf(r));
  });
}

@Riverpod(keepAlive: true)
PlansRepository plansRepository(Ref ref) =>
    PlansRepository(ref.watch(dioProvider), ref.watch(responseCacheProvider));
