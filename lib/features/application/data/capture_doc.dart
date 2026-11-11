/// The three identity photos (`docs/api/profile.md`).
enum CaptureDoc {
  cnicFront('cnic_front', 'CNIC front'),
  cnicBack('cnic_back', 'CNIC back'),
  selfie('selfie', 'Selfie with CNIC');

  new(this.key, this.title);

  /// The API's field and path name.
  final String key;
  final String title;

  bool get isCnic => this != selfie;

  static CaptureDoc? parse(String? key) {
    for (final d in values) {
      if (d.key == key) return d;
    }
    return null;
  }
}
