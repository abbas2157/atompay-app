/// Brief §10: permissions a lending app must never declare (Google Play's
/// personal-loan policy and SECP), and the ones AtomPay is allowed.
library;

/// Exact names, plus every `READ_MEDIA_*`.
const forbiddenPermissions = {
  // Contacts.
  'android.permission.READ_CONTACTS',
  'android.permission.WRITE_CONTACTS',
  'android.permission.GET_ACCOUNTS',
  // Storage and media.
  'android.permission.READ_EXTERNAL_STORAGE',
  'android.permission.WRITE_EXTERNAL_STORAGE',
  'android.permission.MANAGE_EXTERNAL_STORAGE',
  'android.permission.ACCESS_MEDIA_LOCATION',
  // Location.
  'android.permission.ACCESS_FINE_LOCATION',
  'android.permission.ACCESS_COARSE_LOCATION',
  'android.permission.ACCESS_BACKGROUND_LOCATION',
  // Phone state and numbers, calls.
  'android.permission.READ_PHONE_STATE',
  'android.permission.READ_PHONE_NUMBERS',
  'android.permission.CALL_PHONE',
  'android.permission.READ_CALL_LOG',
  'android.permission.WRITE_CALL_LOG',
  'android.permission.PROCESS_OUTGOING_CALLS',
  'android.permission.ANSWER_PHONE_CALLS',
  // SMS.
  'android.permission.READ_SMS',
  'android.permission.SEND_SMS',
  'android.permission.RECEIVE_SMS',
  'android.permission.RECEIVE_MMS',
  'android.permission.RECEIVE_WAP_PUSH',
  // Other apps.
  'android.permission.QUERY_ALL_PACKAGES',
};

/// What AtomPay and its plugins may declare. Anything else is reported so
/// a new plugin can't slip a permission in unnoticed.
const allowedPermissions = {
  'android.permission.INTERNET',
  'android.permission.ACCESS_NETWORK_STATE',
  'android.permission.USE_BIOMETRIC',
  'android.permission.USE_FINGERPRINT',
  'android.permission.CAMERA',
  'android.permission.RECORD_AUDIO',
  'android.permission.POST_NOTIFICATIONS',
  // Added by AndroidX for its own broadcasts; app-private.
  'DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
};

bool isForbidden(String permission) =>
    forbiddenPermissions.contains(permission) ||
    permission.startsWith('android.permission.READ_MEDIA_');

bool isAllowed(String permission) =>
    allowedPermissions.contains(permission) ||
    permission.endsWith('.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION');

/// Every permission a manifest declares (`uses-permission` and
/// `uses-permission-sdk-23`), skipping ones a `tools:node="remove"` drops.
/// Merged manifests have already applied those removals.
Set<String> declaredPermissions(String manifestXml) {
  final tag = RegExp(r'<uses-permission(?:-sdk-23)?\b[^>]*>', dotAll: true);
  final name = RegExp(r'android:name\s*=\s*"([^"]+)"');
  return {
    for (final m in tag.allMatches(manifestXml))
      if (!m.group(0)!.contains('tools:node="remove"'))
        if (name.firstMatch(m.group(0)!) case final n?) n.group(1)!,
  };
}

/// The result of checking one manifest.
class ManifestReport {
  new(Set<String> declared)
    : forbidden = declared.where(isForbidden).toSet(),
      unknown = declared.where((p) => !isForbidden(p) && !isAllowed(p)).toSet();

  final Set<String> forbidden;
  final Set<String> unknown;

  bool get ok => forbidden.isEmpty && unknown.isEmpty;
}
