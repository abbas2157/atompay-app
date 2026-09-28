import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(const FlutterSecureStorage()),
);

/// The bearer token and the last-known user live here and nowhere else
/// (handbook rule 9). Keeps an in-memory copy of the token so the HTTP
/// interceptor can read it synchronously.
class TokenStorage {
  new(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth.token';
  static const _expiresKey = 'auth.expires_at';
  static const _userKey = 'auth.user';

  String? _token;

  /// The token loaded by [load] or saved by [save]. Null when signed out.
  String? get token => _token;

  Future<String?> load() async {
    return _token = await _storage.read(key: _tokenKey);
  }

  Future<DateTime?> expiresAt() async {
    final raw = await _storage.read(key: _expiresKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> save({required String token, required DateTime expiresAt}) {
    _token = token;
    return Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _expiresKey, value: expiresAt.toIso8601String()),
    ]);
  }

  /// The last `/me` response, for offline launch. Contains PII, which is why
  /// it lives in secure storage and not SharedPreferences.
  Future<Map<String, dynamic>?> cachedUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } on FormatException {
      return null;
    }
  }

  Future<void> cacheUser(Map<String, dynamic> json) =>
      _storage.write(key: _userKey, value: jsonEncode(json));

  Future<void> clear() {
    _token = null;
    return Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _expiresKey),
      _storage.delete(key: _userKey),
    ]);
  }
}
