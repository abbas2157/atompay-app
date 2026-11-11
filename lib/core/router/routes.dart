/// Every path in the app (brief §5, route table). Screens navigate with
/// these, never with string literals.
abstract final class Routes {
  // Launch
  static const splash = '/splash';
  static const update = '/update';
  static const maintenance = '/maintenance';
  static const firstRun = '/first-run';
  static const welcome = '/welcome';

  // Auth
  static const login = '/login';
  static const register = '/register';
  static const registerVerify = '/register/verify';
  static const forgot = '/forgot';
  static const forgotVerify = '/forgot/verify';
  static const forgotReset = '/forgot/reset';

  // Home
  static const home = '/home';
  static const notifications = '/home/notifications';

  // Apply
  static const application = '/application';
  static String applicationStep(int step) => '/application?step=$step';

  /// A step opened from Review: Save returns there.
  static String applicationEdit(int step) => '/application?step=$step&edit=1';
  static String applicationDetail(int id) => '/application/history/$id';
  static String capture(String doc) => '/application/capture/$doc';
  static const applicationStatus = '/application/status';
  static const applicationHistory = '/application/history';
  static String document(String doc) => '/profile/document/$doc';

  // Shop
  static const shop = '/shop';
  static String product(int id) => '/shop/$id';
  static const calculator = '/calculator';

  // Ask Atom
  static const atom = '/atom';

  // Orders
  static const plans = '/plans';
  static String plan(int orderId) => '/plans/$orderId';
  static String kfs(int orderId) => '/plans/$orderId/kfs';

  // Account
  static const account = '/account';
  static const settings = '/account/settings';
  static const security = '/account/settings/security';
  static const permissions = '/account/settings/permissions';
  static const notificationSettings = '/account/settings/notifications';
  static const password = '/account/settings/password';
  static const devices = '/account/devices';
  static const deleteAccount = '/account/delete';
  static const about = '/account/about';
  static const ecosystem = '/account/ecosystem';
  static const rate = '/account/rate';

  // Help
  static const help = '/help';
  static String helpTopic(String topic) => '/help/topic/$topic';

  /// A topic opened with one question expanded.
  static String helpQuestion(String topic, String question) =>
      '/help/topic/$topic?q=$question';

  /// A topic opened from Help's search box: the search field is focused.
  static String helpTopicSearch(String topic) => '/help/topic/$topic?search=1';
  static const complaint = '/help/complaint';
  static const complaintSent = '/help/complaint/sent';

  /// The reference is not personal data (brief §5.5).
  static String complaintSentWith(String reference) =>
      '$complaintSent?ref=${Uri.encodeQueryComponent(reference)}';

  // Dev and staging only: the widget gallery (brief §14, Phase 0).
  static const gallery = '/gallery';

  /// Reachable without a token.
  static const public = {
    splash,
    update,
    maintenance,
    firstRun,
    welcome,
    login,
    register,
    registerVerify,
    forgot,
    forgotVerify,
    forgotReset,
  };

  /// Screens that block everything behind them.
  static const gates = {update, maintenance, firstRun};

  /// Paths that only make sense once a limit is approved; without one they
  /// go Home (brief §5.3, guard 6). None of the routes in the brief's table
  /// needs it yet: screens that change with the limit (Home, the income
  /// step) handle both cases themselves.
  static const limitOnly = <String>{};
}
