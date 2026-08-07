class RegistrationResponse {
  const RegistrationResponse({
    required this.success,
    required this.message,
    this.waitlisted = false,
    this.underReview = false,
    this.referenceId,
    this.waitlistNumber,
  });

  final bool success;
  final String message;
  final bool waitlisted;
  final bool underReview;
  final String? referenceId;
  final String? waitlistNumber;

  factory RegistrationResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : null;

    final message = json['message']?.toString().trim().isNotEmpty == true
        ? json['message'].toString().trim()
        : 'Unknown response';

    final waitlisted = _readBool(json['waitlisted']) ||
        _readBool(data?['waitlisted']);

    // Prefer waitlisted over under-review when waitlisted flag is present.
    final underReview = !waitlisted &&
        (_detectUnderReview(json, message) ||
            (data != null && _detectUnderReview(data, message)));

    final referenceId = _readString(
      json['reference_id'] ??
          json['referenceId'] ??
          data?['reference_id'] ??
          data?['referenceId'] ??
          data?['id'],
    );
    final waitlistNumber = _readString(
      json['waitlist_number'] ??
          json['waitlistNumber'] ??
          data?['waitlist_number'] ??
          data?['waitlistNumber'],
    );

    return RegistrationResponse(
      success: _readBool(json['success']),
      message: message,
      waitlisted: waitlisted,
      underReview: underReview,
      referenceId: referenceId,
      waitlistNumber: waitlistNumber,
    );
  }

  /// Backend may reject a duplicate submit with success:false while docs
  /// are still pending review — treat that as under-review, not rejection.
  static bool _detectUnderReview(Map<String, dynamic> json, String message) {
    if (json['under_review'] == true || json['underReview'] == true) {
      return true;
    }

    final status = (json['status'] ??
            json['partner_status'] ??
            json['partnerStatus'] ??
            json['registration_status'] ??
            json['registrationStatus'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();

    if (status.contains('under_review') ||
        status.contains('under-review') ||
        status == 'pending' ||
        status == 'submitted' ||
        status == 'in_review' ||
        status == 'review') {
      return true;
    }

    final lower = message.toLowerCase();
    return lower.contains('under review') ||
        lower.contains('already submitted') ||
        (lower.contains('already') && lower.contains('review'));
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    return false;
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
