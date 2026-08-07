import 'waitlist_status.dart';

class WaitlistStatusModel {
  const WaitlistStatusModel({
    required this.status,
    this.message,
    this.remarks = const [],
    this.formData,
    this.waitlistNumber,
    this.referenceId,
    this.mobileNumber,
  });

  final WaitlistStatus status;
  final String? message;
  final List<String> remarks;
  final Map<String, dynamic>? formData;
  final String? waitlistNumber;
  final String? referenceId;
  final String? mobileNumber;

  factory WaitlistStatusModel.fromJson(Map<String, dynamic> json) {
    final data = _readMap(json['data']) ?? json;

    final statusRaw = _readString(
      data['status'] ??
          data['waitlist_status'] ??
          data['waitlistStatus'] ??
          json['status'],
    );

    final remarks = _readRemarks(
      data['rejection_reason'] ??
          data['rejectionReason'] ??
          data['remarks'] ??
          data['remark'] ??
          data['rejection_reasons'] ??
          data['rejectionReasons'] ??
          json['rejection_reason'] ??
          json['rejectionReason'] ??
          json['remarks'],
    );

    return WaitlistStatusModel(
      status: WaitlistStatus.fromApi(statusRaw),
      message: _readString(json['message'] ?? data['message']),
      remarks: remarks,
      formData: _extractFormData(data),
      waitlistNumber: _readString(
        data['waitlist_number'] ??
            data['waitlistNumber'] ??
            json['waitlist_number'] ??
            json['waitlistNumber'],
      ),
      referenceId: _readString(
        data['reference_id'] ??
            data['referenceId'] ??
            data['id'] ??
            json['reference_id'] ??
            json['referenceId'] ??
            json['id'],
      ),
      mobileNumber: _readString(
        data['mobile_number'] ??
            data['mobileNumber'] ??
            data['profilePhone'] ??
            data['profile_phone'] ??
            _extractFormData(data)?['mobileNumber'] ??
            _extractFormData(data)?['profilePhone'],
      ),
    );
  }

  static Map<String, dynamic>? _readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static List<String> _readRemarks(dynamic value) {
    if (value == null) return const [];

    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final text = value.toString().trim();
    if (text.isEmpty) return const [];
    return [text];
  }

  static Map<String, dynamic>? _extractFormData(Map<String, dynamic> data) {
    final formData = _readMap(data['form_data'] ?? data['formData']);
    if (formData == null) return null;

    final body = _readMap(formData['body']);
    if (body != null && body.isNotEmpty) return body;
    return formData;
  }
}
