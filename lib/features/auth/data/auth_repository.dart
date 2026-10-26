import 'package:atompay_mobile/core/config/device.dart';
import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/storage/token_storage.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
    deviceName: ref.watch(deviceInfoProvider).deviceName,
  ),
);

/// Auth and sessions (handbook §8.6) plus `/me`. Every call that returns a
/// token stores it before returning.
class AuthRepository {
  new(this._api, this._tokens, {required this.deviceName});

  final ApiClient _api;
  final TokenStorage _tokens;
  final String deviceName;

  Future<User> login({required String login, required String password}) {
    return _signIn(
      _api.post(
        '/auth/login',
        data: {
          'login': login.trim(),
          'password': password,
          'device_name': deviceName,
        },
      ),
    );
  }

  // ---- Sign-up (one-time code) ----

  Future<CodeChallenge> register({
    required String name,
    required String login,
    required String password,
    required String passwordConfirmation,
  }) async {
    final data = await _api.post(
      '/auth/register',
      data: {
        'name': name.trim(),
        'login': login.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    return _challenge(data, idKey: 'signup_id');
  }

  Future<CodeChallenge> resendSignupCode(String signupId) async {
    final data = await _api.post(
      '/auth/register/resend',
      data: {'signup_id': signupId},
    );
    return _challenge(data, idKey: 'signup_id');
  }

  Future<User> verifySignup({required String signupId, required String code}) {
    return _signIn(
      _api.post(
        '/auth/register/verify',
        data: {'signup_id': signupId, 'code': code, 'device_name': deviceName},
      ),
    );
  }

  // ---- Forgot password (one-time code) ----

  /// Always `202` for well-formed input, even for an unknown account.
  /// Calling again within 60 s returns the same request (that's "resend").
  Future<CodeChallenge> forgotPassword(String login) async {
    final data = await _api.post(
      '/auth/password/forgot',
      data: {'login': login.trim()},
    );
    return _challenge(data, idKey: 'request_id');
  }

  /// Returns the `reset_token` (valid 15 minutes).
  Future<String> verifyResetCode({
    required String requestId,
    required String code,
  }) async {
    final data = await _api.post(
      '/auth/password/verify',
      data: {'request_id': requestId, 'code': code},
    );
    return _map(data)['reset_token'] as String;
  }

  /// Changes the password (on AtomShop too), signs out every other device
  /// and signs this one in.
  Future<User> resetPassword({
    required String resetToken,
    required String password,
    required String passwordConfirmation,
  }) {
    return _signIn(
      _api.post(
        '/auth/password/reset',
        data: {
          'reset_token': resetToken,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'device_name': deviceName,
        },
      ),
    );
  }

  // ---- Signed in ----

  Future<User> me() async {
    final json = _map(await _api.get('/me'));
    await _tokens.cacheUser(json);
    return User.fromJson(json);
  }

  Future<User?> cachedUser() async {
    final json = await _tokens.cachedUser();
    if (json == null) return null;
    try {
      return User.fromJson(json);
    } on Object {
      return null;
    }
  }

  Future<bool> hasToken() async => await _tokens.load() != null;

  /// Best effort: the local token is cleared even when the call fails.
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on Object {
      // Offline or already revoked: signing out locally is what matters.
    } finally {
      await _tokens.clear();
    }
  }

  Future<void> logoutAll() async {
    await _api.post('/auth/logout-all');
    await _tokens.clear();
  }

  Future<List<DeviceSession>> sessions() async {
    final data = await _api.get('/auth/sessions');
    return [
      for (final item in data as List) DeviceSession.fromJson(_map(item)),
    ];
  }

  Future<void> revokeSession(int id) => _api.delete('/auth/sessions/$id');

  Future<void> clearLocalSession() => _tokens.clear();

  /// Deletes the account (both stores require it in-app). The server revokes
  /// every token, so the local one goes too.
  Future<void> deleteAccount(String password) async {
    await _api.post('/me/delete', data: {'password': password});
    await _tokens.clear();
  }

  Future<User> _signIn(Future<dynamic> call) async {
    final result = AuthResult.fromJson(_map(await call));
    await _tokens.save(token: result.token, expiresAt: result.expiresAt);
    final userJson = result.user.toJson();
    await _tokens.cacheUser(userJson);
    return result.user;
  }

  /// `202` body of register/resend (`signup_id`) or forgot (`request_id`).
  static CodeChallenge _challenge(Object? data, {required String idKey}) {
    final json = _map(data);
    return CodeChallenge(
      id: json[idKey] as String,
      channel: switch (json['channel']) {
        'email' => CodeChannel.email,
        'whatsapp' => CodeChannel.whatsapp,
        _ => CodeChannel.unknown,
      },
      destination: json['destination'] as String? ?? '',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
      resendIn: (json['resend_in'] as num?)?.toInt() ?? 60,
    );
  }

  static Map<String, dynamic> _map(Object? data) =>
      (data! as Map).cast<String, dynamic>();
}
