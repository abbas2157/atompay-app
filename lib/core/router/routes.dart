/// Route paths (handbook §5.1).
abstract final class Routes {
  static const splash = '/splash';
  static const update = '/update';

  /// Guest home: the website's landing page. Where signed-out users land.
  static const welcome = '/welcome';

  static const login = '/login';
  static const register = '/register';
  static const registerVerify = '/register/verify';
  static const forgot = '/forgot';
  static const forgotVerify = '/forgot/verify';
  static const forgotReset = '/forgot/reset';

  static const home = '/home';
  static const notifications = '/home/notifications';

  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static String profileDocument(String doc) => '/profile/document/$doc';

  /// Profile form that continues to the income form once saved (banner
  /// action `apply`).
  static const profileEditThenApply = '/profile/edit?next=application';

  static const application = '/application';
  static const applicationStatus = '/application/status';
  static const applicationHistory = '/application/history';

  /// Public income estimator.
  static const estimate = '/estimate';

  static const plans = '/plans';
  static String plan(int orderId) => '/plans/$orderId';

  /// Public plan calculator.
  static const calculator = '/calculator';

  static const account = '/account';
  static const accountDevices = '/account/devices';
  static const accountNotifications = '/account/notifications';

  /// Reachable while signed out.
  static const signedOutOnly = {welcome, login, register, registerVerify};
  static const passwordReset = {forgot, forgotVerify, forgotReset};

  /// Reachable signed in or out.
  static const public = {estimate, calculator};
  static const launch = {splash, update};
}
