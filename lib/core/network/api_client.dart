import 'dart:async';

import 'package:atompay_mobile/core/config/env.dart';
import 'package:atompay_mobile/core/fake/fake_server.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/network/error_mapper.dart';
import 'package:atompay_mobile/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Things any request can learn that the whole app must react to. The
/// session and launch controllers listen; the network layer never imports
/// them.
sealed class ApiEvent {
  const new();
}

/// A signed-in call got 401 or 403: the token is gone.
final class SessionLost extends ApiEvent {
  const new({this.message});

  /// The 403 message ("Please sign in with an AtomShop customer
  /// account."), shown as written. Null for a 401.
  final String? message;
}

/// A 503: the server is down for maintenance.
final class MaintenanceDetected extends ApiEvent {
  const new();
}

final apiEventsProvider = Provider<StreamController<ApiEvent>>((ref) {
  final controller = StreamController<ApiEvent>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

/// The in-memory API. Answers everything under `FAKE_API=true`, and the
/// brief §7.2 endpoints the server hasn't shipped.
final fakeServerProvider = Provider<FakeServer>(
  (ref) => FakeServer(
    scenario: FakeScenario.parse(Env.fakeScenario),
    trustAnyToken: !Env.fakeEverything,
  ),
);

final dioProvider = Provider<Dio>((ref) {
  final tokens = ref.watch(tokenStorageProvider);
  final events = ref.watch(apiEventsProvider);
  final fake = ref.watch(fakeServerProvider);
  return buildDio(
    tokens: tokens,
    events: events,
    adapter: RoutingAdapter(
      live: IOHttpClientAdapter(),
      fake: fake,
      useFake: (o) => Env.useFakeFor(o.uri.path),
    ),
  );
});

Dio buildDio({
  required TokenStorage tokens,
  required StreamController<ApiEvent> events,
  HttpClientAdapter? adapter,
  String baseUrl = Env.apiBaseUrl,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.add(AuthInterceptor(tokens: tokens, events: events));
  // No body logging, ever: requests carry CNICs, incomes and tokens.
  return dio;
}

/// Adds the bearer token, and turns 401/403 on a signed-in call into
/// [SessionLost] after clearing the token, and any 503 into
/// [MaintenanceDetected].
class AuthInterceptor extends Interceptor {
  new({required this.tokens, required this.events});

  final TokenStorage tokens;
  final StreamController<ApiEvent> events;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokens.token;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final mapped = ErrorMapper.map(err);
    final hadToken = err.requestOptions.headers.containsKey('Authorization');
    if (hadToken && (mapped is Unauthenticated || mapped is Forbidden)) {
      await tokens.clear();
      events.add(
        SessionLost(message: mapped is Forbidden ? mapped.message : null),
      );
    } else if (mapped is Server && mapped.isMaintenance) {
      events.add(const MaintenanceDetected());
    }
    handler.next(err.copyWith(error: mapped));
  }
}

/// Riverpod 3 retries failed providers on its own. The app doesn't: every
/// error screen has its own "Try again", and a 404 or 422 never heals.
Duration? noRetry(int retryCount, Object error) => null;

/// Runs [call] and rethrows any failure as an [ApiException].
Future<T> guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ErrorMapper.map(e);
  }
}

/// Reads `{ "data": ... }` as an object.
Map<String, dynamic> dataOf(Response<dynamic> response) =>
    dataIn(response.data);

/// Reads `{ "data": [ ... ] }` as a list of objects.
List<Map<String, dynamic>> listOf(Response<dynamic> response) =>
    listIn(response.data);

/// [dataOf] for a body that was cached rather than just received.
Map<String, dynamic> dataIn(Object? body) {
  if (body is Map && body['data'] is Map) {
    return (body['data'] as Map).cast<String, dynamic>();
  }
  throw const Server(statusCode: 0);
}

/// [listOf] for a body that was cached rather than just received.
List<Map<String, dynamic>> listIn(Object? body) {
  if (body is Map && body['data'] is List) {
    return [
      for (final item in body['data'] as List)
        (item as Map).cast<String, dynamic>(),
    ];
  }
  throw const Server(statusCode: 0);
}
