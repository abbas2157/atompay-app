import 'dart:convert';

import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/storage/token_storage.dart';
import 'package:atompay_mobile/core/utils/app_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Data shown from the last good response while offline (brief §8,
/// "Offline with cache"). [savedAt] is non-null only when [data] came from
/// the cache, for "Showing … from 10:42 am".
@immutable
class Cached<T> {
  const new(this.data, {this.savedAt});

  final T data;
  final DateTime? savedAt;

  bool get fromCache => savedAt != null;
}

final responseCacheProvider = Provider<ResponseCache>(
  (ref) => ResponseCache(secureStorage),
);

/// The last good JSON of a few screens (Home, Orders, Notifications). It
/// can hold personal data, so it lives in secure storage, and sign-out
/// wipes it with the token (brief §12).
class ResponseCache {
  new(this._storage);

  final FlutterSecureStorage _storage;

  static const _prefix = 'cache.';

  Future<void> put(String key, Object? json) => _storage.write(
    key: '$_prefix$key',
    value: jsonEncode({
      'saved_at': AppClock.now().toIso8601String(),
      'json': json,
    }),
  );

  Future<(Object?, DateTime)?> get(String key) async {
    final raw = await _storage.read(key: '$_prefix$key');
    if (raw == null) return null;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return (map['json'], DateTime.parse(map['saved_at'] as String));
    } on Object {
      return null;
    }
  }

  /// Every cached response.
  Future<void> clear() async {
    // Copy the keys first: deleting while iterating the live map throws.
    final keys = [
      for (final key in (await _storage.readAll()).keys)
        if (key.startsWith(_prefix)) key,
    ];
    for (final key in keys) {
      await _storage.delete(key: key);
    }
  }

  /// Fetches with [load] and caches the JSON. When the phone is offline or
  /// the call times out, falls back to the cached copy; any other error,
  /// or no copy, rethrows.
  Future<Cached<T>> fetch<T>({
    required String key,
    required Future<Object?> Function() load,
    required T Function(Object? json) parse,
  }) async {
    try {
      final json = await load();
      final data = parse(json);
      await put(key, json);
      return Cached(data);
    } on ApiException catch (e) {
      if (e is! Offline && e is! Timeout) rethrow;
      final hit = await get(key);
      if (hit == null) rethrow;
      return Cached(parse(hit.$1), savedAt: hit.$2);
    }
  }
}
