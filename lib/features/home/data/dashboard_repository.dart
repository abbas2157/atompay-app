import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/storage/response_cache.dart';
import 'package:atompay_mobile/features/home/data/dashboard_models.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_repository.g.dart';

class DashboardRepository {
  new(this._dio, this._cache);

  final Dio _dio;
  final ResponseCache _cache;

  /// `GET /dashboard`, falling back to the last copy when offline.
  Future<Cached<Dashboard>> dashboard() => _cache.fetch(
    key: 'dashboard',
    load: () => guard(() async => (await _dio.get<dynamic>('/dashboard')).data),
    parse: (body) => Dashboard.fromJson(dataIn(body)),
  );
}

@Riverpod(keepAlive: true)
DashboardRepository dashboardRepository(Ref ref) => DashboardRepository(
  ref.watch(dioProvider),
  ref.watch(responseCacheProvider),
);
