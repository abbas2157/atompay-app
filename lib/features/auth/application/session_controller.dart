import 'dart:async';

import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/storage/response_cache.dart';
import 'package:atompay_mobile/core/storage/token_storage.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:atompay_mobile/features/auth/data/auth_repository.dart';
import 'package:atompay_mobile/features/notifications/data/push_service.dart';
import 'package:flutter/painting.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_controller.g.dart';

/// Who is signed in. The router reads this; screens never store a token.
sealed class SessionState {
  const new();
}

/// Launching: the token hasn't been checked yet.
final class SessionUnknown extends SessionState {
  const new();
}

final class SignedIn extends SessionState {
  const new(this.user, {this.offline = false});

  final User user;

  /// `/me` couldn't be reached at launch; showing the cached user.
  final bool offline;
}

final class SignedOut extends SessionState {
  const new({this.reason});

  /// Why the session ended, shown once on Sign in ("You've been signed
  /// out", or the 403's own message). Null after a normal sign-out.
  final String? reason;
}

@Riverpod(keepAlive: true)
class Session extends _$Session {
  StreamSubscription<ApiEvent>? _events;

  @override
  SessionState build() {
    _events = ref
        .watch(apiEventsProvider)
        .stream
        .where((e) => e is SessionLost)
        .cast<SessionLost>()
        .listen((e) => _lost(e.message));
    ref.onDispose(() => _events?.cancel());
    return const SessionUnknown();
  }

  TokenStorage get _tokens => ref.read(tokenStorageProvider);
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Launch: token, then `GET /me`. Offline keeps the cached user.
  Future<void> restore() async {
    final token = await _tokens.load();
    if (token == null) {
      state = const SignedOut();
      return;
    }
    try {
      final (user, json) = await _repo.me();
      await _tokens.cacheUser(json);
      state = SignedIn(user);
    } on Unauthenticated {
      // The interceptor has cleared the token and emitted SessionLost.
      state = const SignedOut();
    } on Forbidden catch (e) {
      state = SignedOut(reason: e.message);
    } on ApiException {
      final cached = await _tokens.cachedUser();
      state = cached == null
          ? const SignedOut()
          : SignedIn(User.fromJson(cached), offline: true);
    }
  }

  /// After sign-in, sign-up verify or a password reset.
  Future<void> start(AuthSession session) async {
    await _tokens.save(token: session.token, expiresAt: session.expiresAt);
    await _tokens.cacheUser(session.user.toJson());
    state = SignedIn(session.user);
  }

  /// Re-reads `/me` (KYC status changes on the server).
  Future<void> refreshUser() async {
    if (state is! SignedIn) return;
    try {
      final (user, json) = await _repo.me();
      await _tokens.cacheUser(json);
      state = SignedIn(user);
    } on ApiException {
      // Keep what we have; a 401 arrives through SessionLost.
    }
  }

  /// Sign out of this phone. The server call is best effort.
  Future<void> signOut() async {
    // Stop pushes to this phone while the token still works.
    await unregisterPush(ref);
    try {
      await _repo.logout();
    } on ApiException {
      // Signed out locally either way.
    }
    await _clear(const SignedOut());
  }

  /// Sign out of every device, this one included.
  Future<void> signOutEverywhere() async {
    await _repo.logoutAll();
    await _clear(const SignedOut());
  }

  /// The account is gone (deleted, or every session ended).
  Future<void> ended() => _clear(const SignedOut());

  Future<void> _lost(String? message) async {
    if (state is SignedOut) return;
    await _clear(SignedOut(reason: message ?? "You've been signed out"));
  }

  Future<void> _clear(SignedOut next) async {
    await Future.wait([
      _tokens.clear(),
      ref.read(responseCacheProvider).clear(),
    ]);
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    state = next;
  }

  /// Shown once on Sign in, then forgotten.
  void consumeReason() {
    if (state case SignedOut(reason: != null)) state = const SignedOut();
  }
}

/// The signed-in user's id, or null. Every user-scoped provider watches
/// this, so signing out drops their cached data.
@Riverpod(keepAlive: true)
int? sessionUserId(Ref ref) => switch (ref.watch(sessionProvider)) {
  SignedIn(:final user) => user.id,
  _ => null,
};

@Riverpod(keepAlive: true)
User? currentUser(Ref ref) => switch (ref.watch(sessionProvider)) {
  SignedIn(:final user) => user,
  _ => null,
};
