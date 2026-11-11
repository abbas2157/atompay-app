import 'package:atompay_mobile/core/utils/app_clock.dart';
import 'package:intl/intl.dart';

/// `10 Dec 2026`.
String dayMonthYear(DateTime d) => DateFormat('d MMM yyyy').format(d);

/// `10 Dec`.
String dayMonth(DateTime d) => DateFormat('d MMM').format(d);

/// `10:42 am`.
String clock(DateTime d) => DateFormat('h:mm a').format(d).toLowerCase();

/// `Dec 2026`.
String monthYear(DateTime d) => DateFormat('MMM yyyy').format(d);

/// `2026-12-10`, the API's date format.
String apiDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Parses an API date or timestamp; null for null or junk.
DateTime? parseApiDate(String? raw) =>
    raw == null ? null : DateTime.tryParse(raw)?.toLocal();

/// "Just now", "5 min ago", "3 h ago", "Yesterday", or a date.
String relative(DateTime when, {DateTime? now}) {
  final n = now ?? AppClock.now();
  final diff = n.difference(when);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24 && n.day == when.day) return '${diff.inHours} h ago';
  final yesterday = DateTime(n.year, n.month, n.day - 1);
  if (when.year == yesterday.year &&
      when.month == yesterday.month &&
      when.day == yesterday.day) {
    return 'Yesterday';
  }
  return when.year == n.year ? dayMonth(when) : dayMonthYear(when);
}

/// `0:48` for a countdown.
String countdown(Duration d) {
  final s = d.inSeconds.clamp(0, 359999);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
