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

  /// Defaults to the live API. For a local XAMPP server, override with
  /// `http://10.0.2.2/atompay/api/v1` (Android emulator),
  /// `http://<PC-LAN-IP>/atompay/api/v1` (real phone) or
  /// `http://localhost/atompay/api/v1` (iOS simulator).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://atompay.shop/api/v1',
  );

  static bool get isProd => flavor == Flavor.prod;
}
