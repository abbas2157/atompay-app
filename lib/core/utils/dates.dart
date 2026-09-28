import 'package:intl/intl.dart';

/// API dates are `YYYY-MM-DD`; timestamps are ISO-8601 UTC. Show local time.
abstract final class Dates {
  static final _list = DateFormat('d MMM yyyy');
  static final _long = DateFormat('EEEE, d MMMM');
  static final _api = DateFormat('yyyy-MM-dd');

  /// `24 Oct 2026`, for lists.
  static String short(DateTime d) => _list.format(d.toLocal());

  /// `Thursday, 24 October`, for the next-due card.
  static String long(DateTime d) => _long.format(d.toLocal());

  /// `2026-10-24`, for request bodies. Uses the calendar date as picked.
  static String api(DateTime d) => _api.format(d);

  /// Parses a `YYYY-MM-DD` date as a local calendar date (no time zone shift).
  static DateTime? parseDate(String? v) {
    if (v == null || v.isEmpty) return null;
    final p = DateTime.tryParse(v);
    return p == null ? null : DateTime(p.year, p.month, p.day);
  }
}
