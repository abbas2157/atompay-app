import 'package:atompay_mobile/core/utils/pk_formatters.dart';
import 'package:atompay_mobile/l10n/gen/app_localizations.dart';

/// Client checks for fast feedback only. The server's 422 is authoritative
/// and its message replaces these.
class Validators {
  const new(this.l10n);

  final AppLocalizations l10n;

  String? required(String v) => v.trim().isEmpty ? l10n.fieldRequired : null;

  /// Email or Pakistani mobile. With [emailOnly], an email is required.
  String? login(String v, {bool emailOnly = false}) {
    final t = v.trim();
    if (t.isEmpty) return l10n.fieldRequired;
    if (Pk.isEmail(t)) return null;
    if (emailOnly) return l10n.invalidEmail;
    if (Pk.looksLikeMobile(t)) {
      return Pk.isValidMobile(t) ? null : l10n.invalidMobile;
    }
    return t.contains('@') ? l10n.invalidEmail : l10n.invalidLogin;
  }

  String? newPassword(String v) {
    if (v.isEmpty) return l10n.fieldRequired;
    return v.length < 8 ? l10n.passwordTooShort : null;
  }

  String? confirmation(String v, String password) {
    if (v.isEmpty) return l10n.fieldRequired;
    return v == password ? null : l10n.passwordsDontMatch;
  }

  String? cnic(String v) {
    if (v.trim().isEmpty) return l10n.fieldRequired;
    return Pk.isValidCnic(v) ? null : l10n.invalidCnic;
  }

  String? mobile(String v) {
    if (v.trim().isEmpty) return l10n.fieldRequired;
    return Pk.isValidMobile(v) ? null : l10n.invalidMobile;
  }
}
