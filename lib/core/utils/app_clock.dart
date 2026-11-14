/// "Now" for anything shown on screen (due in 3 days, 2 hours ago, date of
/// birth limits). Tests and golden images pin it; durations such as the
/// 429 countdown keep using the real clock.
abstract final class AppClock {
  static DateTime Function() _now = DateTime.now;

  static DateTime now() => _now();

  /// Tests only.
  static void pin(DateTime at) => _now = () => at;

  /// Tests only.
  static void reset() => _now = DateTime.now;
}
