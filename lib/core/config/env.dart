/// Build flavour and API base URL, injected at build time with
/// `--dart-define-from-file=env/<flavor>.json`.
enum Flavor {
  dev,
  staging,
  prod;

  static Flavor parse(String value) => Flavor.values.firstWhere(
    (f) => f.name == value,
    orElse: () => Flavor.dev,
  );
}

abstract final class Env {
  static final Flavor flavor = Flavor.parse(
    const String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
  );

  /// Dev default is the Android emulator's alias for the host PC.
  /// On a real phone, override with the PC's LAN IP; on the iOS simulator,
  /// use `http://localhost/atompay/api/v1`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2/atompay/api/v1',
  );

  static bool get isProd => flavor == Flavor.prod;
}
