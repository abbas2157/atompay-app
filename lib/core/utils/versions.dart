import 'package:pub_semver/pub_semver.dart';

/// True when [current] is below [minimum], comparing major.minor.patch only.
/// Build numbers (`+7`) and flavour suffixes (`-dev`, `-staging`) are
/// ignored: in semver `1.0.0-dev` is a pre-release *below* `1.0.0`, which
/// would lock dev builds out. Unparseable input never blocks the app.
bool isBelowMinVersion(String current, String? minimum) {
  if (minimum == null || minimum.isEmpty) return false;
  try {
    return _core(current) < _core(minimum);
  } on FormatException {
    return false;
  }
}

Version _core(String v) {
  final parsed = Version.parse(v.trim());
  return Version(parsed.major, parsed.minor, parsed.patch);
}
