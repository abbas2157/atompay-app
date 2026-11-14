/// Where the customer's identity check stands: `User.kycStatus` and
/// `Profile.status` on the API. Anything unknown reads as [notStarted].
enum KycStatus {
  notStarted,
  pending,
  verified,
  rejected;

  static KycStatus parse(String? value) => switch (value) {
    'pending' => pending,
    'verified' => verified,
    'rejected' => rejected,
    _ => notStarted,
  };
}

/// Where one income application stands (`Assessment.status`).
enum AssessmentStatus {
  pending,
  approved,
  conditional,
  rejected,

  /// A status this build doesn't know; shown with the server's label.
  unknown;

  static AssessmentStatus parse(String? value) => switch (value) {
    'pending' => pending,
    'approved' => approved,
    'conditional' => conditional,
    'rejected' => rejected,
    _ => unknown,
  };

  bool get isApproved => this == approved || this == conditional;
}
