import 'package:atompay_mobile/core/config/device.dart';
import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

/// Sign in, sign up, reset, sessions and the account itself.
class AuthRepository {
  new(this._dio, this._device);

  final Dio _dio;
  final DeviceInfo _device;

  Future<AuthSession> login({
    required String login,
    required String password,
  }) => guard(() async {
    final r = await _dio.post<dynamic>(
      '/auth/login',
      data: {
        'login': login.trim(),
        'password': password,
        'device_name': await _device.name(),
      },
    );
    return AuthSession.fromJson(dataOf(r));
  });

  Future<CodeSent> register({
    required String name,
    required String login,
    required String password,
    required String passwordConfirmation,
  }) => guard(() async {
    final r = await _dio.post<dynamic>(
      '/auth/register',
      data: {
        'name': name.trim(),
        'login': login.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    return CodeSent.fromJson(dataOf(r));
  });

  Future<CodeSent> resendSignupCode(String signupId) => guard(() async {
    final r = await _dio.post<dynamic>(
      '/auth/register/resend',
      data: {'signup_id': signupId},
    );
    return CodeSent.fromJson(dataOf(r));
  });

  Future<AuthSession> verifySignup({
    required String signupId,
    required String code,
  }) => guard(() async {
    final r = await _dio.post<dynamic>(
      '/auth/register/verify',
      data: {
        'signup_id': signupId,
        'code': code,
        'device_name': await _device.name(),
      },
    );
    return AuthSession.fromJson(dataOf(r));
  });

  Future<CodeSent> forgotPassword(String login) => guard(() async {
    final r = await _dio.post<dynamic>(
      '/auth/password/forgot',
      data: {'login': login.trim()},
    );
    return CodeSent.fromJson(dataOf(r));
  });

  /// Returns the reset token.
  Future<String> verifyResetCode({
    required String requestId,
    required String code,
  }) => guard(() async {
    final r = await _dio.post<dynamic>(
      '/auth/password/verify',
      data: {'request_id': requestId, 'code': code},
    );
    return dataOf(r)['reset_token'] as String;
  });

  Future<AuthSession> resetPassword({
    required String resetToken,
    required String password,
    required String passwordConfirmation,
  }) => guard(() async {
    final r = await _dio.post<dynamic>(
      '/auth/password/reset',
      data: {
        'reset_token': resetToken,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'device_name': await _device.name(),
      },
    );
    return AuthSession.fromJson(dataOf(r));
  });

  /// Returns the user and the raw JSON, which is cached for offline launch.
  Future<(User, Map<String, dynamic>)> me() => guard(() async {
    final r = await _dio.get<dynamic>('/me');
    final json = dataOf(r);
    return (User.fromJson(json), json);
  });

  Future<void> logout() => guard(() => _dio.post<dynamic>('/auth/logout'));

  /// Signs out every device, this one included.
  Future<void> logoutAll() =>
      guard(() => _dio.post<dynamic>('/auth/logout-all'));

  Future<List<DeviceSession>> sessions() => guard(() async {
    final r = await _dio.get<dynamic>('/auth/sessions');
    return listOf(r).map(DeviceSession.fromJson).toList();
  });

  Future<void> endSession(int id) =>
      guard(() => _dio.delete<dynamic>('/auth/sessions/$id'));

  /// Brief §7.2: 204, and every other session is signed out.
  Future<void> changePassword({
    required String current,
    required String password,
    required String passwordConfirmation,
  }) => guard(
    () => _dio.post<dynamic>(
      '/me/password',
      data: {
        'current_password': current,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    ),
  );

  /// 409 `outstanding_balance` while anything is owed.
  Future<void> deleteAccount(String password) => guard(
    () => _dio.post<dynamic>('/me/delete', data: {'password': password}),
  );

  Future<bool> emailAlerts() => guard(() async {
    final r = await _dio.get<dynamic>('/me/preferences');
    return dataOf(r)['email_alerts'] == true;
  });

  Future<bool> setEmailAlerts({required bool on}) => guard(() async {
    final r = await _dio.patch<dynamic>(
      '/me/preferences',
      data: {'email_alerts': on},
    );
    return dataOf(r)['email_alerts'] == true;
  });
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    AuthRepository(ref.watch(dioProvider), ref.watch(deviceInfoProvider));
