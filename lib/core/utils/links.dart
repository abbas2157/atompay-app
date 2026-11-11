import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link outside the app (browser, store, dialer, mail, WhatsApp).
/// Never puts a token or personal data in the URL.
abstract final class Links {
  static Future<bool> open(String? url) async {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) showToast("Couldn't open that link.", error: true);
      return ok;
    } on Object {
      showToast("Couldn't open that link.", error: true);
      return false;
    }
  }

  /// `03001234567` or `+92…` → wa.me.
  static Future<bool> whatsapp(String number) {
    var d = number.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0')) d = '92${d.substring(1)}';
    return open('https://wa.me/$d');
  }

  static Future<bool> call(String number) =>
      open('tel:${number.replaceAll(' ', '')}');

  static Future<bool> email(String address) => open('mailto:$address');
}
