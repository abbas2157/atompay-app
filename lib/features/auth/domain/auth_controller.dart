import 'dart:async';

import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:atompay_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Handbook §3.5.
@immutable
sealed class AuthState {
  const new();
}

/// Before launch has checked the stored token (splash).
final class AuthUnknown extends AuthState {
  const new();
}

final class SignedIn extends AuthState {
  const new(this.user, {this.offline = false});

  final User user;

  /// Launched without a connection, showing the cached user.
  final bool offline;
}

final class SignedOut extends AuthState {
  const new({this.message});

  /// A server message to show once (a `403` on a signed-in call).
  final String? message;
}

/// Launched with a stored token but no connection and no cached user.
final class AuthOffline extends AuthState {
  const new();
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final sub = ref
        .watch(sessionEventsProvider)
        .ended
        .listen((message) => state = SignedOut(message: message));
    ref.onDispose(sub.cancel);
    return const AuthUnknown();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Launch: stored token → `GET /me`.
  Future<void> restore() async {
    if (!await _repo.hasToken()) {
      state = const SignedOut();
      return;
    }
    try {
      state = SignedIn(await _repo.me());
    } on Unauthorized {
      // The interceptor already cleared the token and emitted the event.
      state = const SignedOut();
    } on Forbidden catch (e) {
      state = SignedOut(message: e.message);
    } on ApiException {
      final cached = await _repo.cachedUser();
      state = cached == null
          ? const AuthOffline()
          : SignedIn(cached, offline: true);
    }
  }

  /// After login, sign-up verify or password reset stored a token.
  void signedIn(User user) => state = SignedIn(user);

  /// Refetch `/me` (e.g. after the profile changes `kyc_status`).
  Future<void> refreshUser() async {
    if (state is! SignedIn) return;
    try {
      state = SignedIn(await _repo.me());
    } on ApiException {
      // 401/403 are handled by the interceptor; anything else keeps the
      // current user.
    }
  }

  Future<void> signOut() async {
    await _repo.logout();
    state = const SignedOut();
  }

  /// Revokes every device. Throws on failure so the screen can say so.
  Future<void> signOutEverywhere() async {
    await _repo.logoutAll();
    state = const SignedOut();
  }

  /// Revoking the current device from the sessions list is a sign-out.
  Future<void> signedOutLocally() async {
    await _repo.clearLocalSession();
    state = const SignedOut();
  }

  /// The one-shot [SignedOut.message] has been shown.
  void clearMessage() {
    if (state case SignedOut(message: final m?) when m.isNotEmpty) {
      state = const SignedOut();
    }
  }
}
