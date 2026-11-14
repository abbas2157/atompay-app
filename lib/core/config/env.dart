/// Build flavour, API base URL and which repositories run on fakes. Injected
/// at build time with `--dart-define-from-file=env/<flavor>.json`.
enum Flavor {
  dev,
  staging,
  prod;

  static Flavor parse(String value) => Flavor.values.firstWhere(
    (f) => f.name == value,
    orElse: () => Flavor.dev,
  );
}

/// The endpoints in brief §7.2 that the server is still building. Until one
/// is listed in `LIVE_APIS`, its repository answers from the fake, with
/// exactly the documented shape.
enum NewApi {
  /// `GET /areas?city_id=` and `area_id` on the profile.
  areas('areas'),

  /// `GET /plan-preview`.
  planPreview('plan_preview'),

  /// `GET /products`, `/products/categories`, `/products/{id}`.
  products('products'),

  /// `GET /plans/{order}/kfs`, `POST /plans/{order}/kfs/send`.
  kfs('kfs'),

  /// `POST|GET /complaints` and `complaint_topics` in `/options`.
  complaints('complaints'),

  /// `GET /ask-atom/chips`, `POST /ask-atom`.
  askAtom('ask_atom'),

  /// `POST /me/password`.
  changePassword('change_password');

  new(this.key);

  final String key;
}

abstract final class Env {
  static final Flavor flavor = Flavor.parse(
    const String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
  );

  /// Production by default. For a local XAMPP server use
  /// `http://10.0.2.2/atompay/api/v1` (Android emulator),
  /// `http://<PC-LAN-IP>/atompay/api/v1` (real phone) or
  /// `http://localhost/atompay/api/v1` (iOS simulator).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://atompay.shop/api/v1',
  );

  /// `FAKE_API=true` runs every repository on its fake: no server needed.
  static const bool fakeEverything = bool.fromEnvironment('FAKE_API');

  /// Comma-separated [NewApi.key]s that the server has shipped, e.g.
  /// `LIVE_APIS=areas,plan_preview`. `all` switches every one on.
  static const String _liveApis = String.fromEnvironment('LIVE_APIS');

  static final Set<String> _live = {
    for (final key in _liveApis.split(',')) key.trim(),
  }..remove('');

  /// Whether [api] should call the server rather than its fake.
  static bool isLive(NewApi api) =>
      !fakeEverything && (_live.contains('all') || _live.contains(api.key));

  /// Which customer the fake server plays: `newCustomer`, `approved`,
  /// `repaying` (default) or `late`.
  static const String fakeScenario = String.fromEnvironment('FAKE_SCENARIO');

  static bool get isProd => flavor == Flavor.prod;

  /// The §7.2 endpoint a request path belongs to, or null for a live one.
  static NewApi? newApiFor(String path) {
    final p = path.replaceFirst(RegExp('^.*/api/v1'), '');
    if (p.startsWith('/areas')) return NewApi.areas;
    if (p.startsWith('/plan-preview')) return NewApi.planPreview;
    if (p.startsWith('/products')) return NewApi.products;
    if (RegExp(r'^/plans/\d+/kfs').hasMatch(p)) return NewApi.kfs;
    if (p.startsWith('/complaints')) return NewApi.complaints;
    if (p.startsWith('/ask-atom')) return NewApi.askAtom;
    if (p == '/me/password') return NewApi.changePassword;
    return null;
  }

  /// Whether a request to [path] should be answered by the fake server.
  ///
  /// Never in a production build: a customer must not see made-up
  /// products, terms or answers, or a complaint that goes nowhere. There an
  /// endpoint the server hasn't shipped fails like any other (404), and its
  /// screen shows the error state.
  static bool useFakeFor(String path) {
    if (fakeEverything) return true;
    if (isProd) return false;
    final api = newApiFor(path);
    return api != null && !isLive(api);
  }
}
