enum WaitlistStatus {
  underReview,
  approved,
  rejected,
  unknown;

  static WaitlistStatus fromApi(String? raw) {
    final normalized = raw
            ?.trim()
            .toUpperCase()
            .replaceAll('-', '_')
            .replaceAll(' ', '_') ??
        '';

    switch (normalized) {
      case 'UNDER_REVIEW':
      case 'IN_REVIEW':
      case 'PENDING':
      case 'SUBMITTED':
      case 'WAITLISTED':
        return WaitlistStatus.underReview;
      case 'APPROVED':
      case 'ACTIVE':
        return WaitlistStatus.approved;
      case 'REJECTED':
      case 'FAILED':
        return WaitlistStatus.rejected;
      default:
        return WaitlistStatus.unknown;
    }
  }
}
