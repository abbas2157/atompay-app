import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/features/launch/data/app_config.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'config_repository.g.dart';

/// Launch config and the pickers' lists. All public except cities and areas.
class ConfigRepository {
  new(this._dio);

  final Dio _dio;

  Future<AppConfig> appConfig() => guard(() async {
    final r = await _dio.get<dynamic>('/app-config');
    return AppConfig.fromJson(dataOf(r));
  });

  Future<FormOptions> options() => guard(() async {
    final r = await _dio.get<dynamic>('/options');
    return FormOptions.fromJson(dataOf(r));
  });

  Future<List<Place>> cities() => guard(() async {
    final r = await _dio.get<dynamic>('/cities');
    return listOf(r).map(Place.fromJson).toList();
  });

  /// Brief §7.2. Sorted by title on the server; 422 for an unknown city.
  Future<List<Place>> areas(int cityId) => guard(() async {
    final r = await _dio.get<dynamic>(
      '/areas',
      queryParameters: {'city_id': cityId},
    );
    return listOf(r).map(Place.fromJson).toList();
  });
}

@Riverpod(keepAlive: true)
ConfigRepository configRepository(Ref ref) =>
    ConfigRepository(ref.watch(dioProvider));

/// `/options` for the session.
@Riverpod(keepAlive: true)
Future<FormOptions> formOptions(Ref ref) =>
    ref.watch(configRepositoryProvider).options();

/// `/cities` for the session: the list changes rarely.
@Riverpod(keepAlive: true)
Future<List<Place>> cities(Ref ref) =>
    ref.watch(configRepositoryProvider).cities();

@riverpod
Future<List<Place>> areas(Ref ref, int cityId) =>
    ref.watch(configRepositoryProvider).areas(cityId);
