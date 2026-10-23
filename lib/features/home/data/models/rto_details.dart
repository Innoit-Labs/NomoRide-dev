/// RTO (return-to-origin) payload returned after a failed forward delivery.
class RtoDropLocation {
  const RtoDropLocation({
    this.hubName,
    this.address,
    this.fullAddress,
    this.city,
    this.latitude,
    this.longitude,
    this.contactPerson,
    this.contactMobile,
  });

  final String? hubName;
  final String? address;
  final String? fullAddress;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? contactPerson;
  final String? contactMobile;

  String? get displayAddress {
    final full = fullAddress?.trim();
    if (full != null && full.isNotEmpty) return full;
    final short = address?.trim();
    if (short != null && short.isNotEmpty) return short;
    return null;
  }

  factory RtoDropLocation.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const RtoDropLocation();
    return RtoDropLocation(
      hubName: _readString(
        json['hub_name'] ?? json['hubName'] ?? json['organization_name'],
      ),
      address: _readString(json['address']),
      fullAddress: _readString(
        json['full_address'] ?? json['fullAddress'],
      ),
      city: _readString(json['city']),
      latitude: _readDouble(json['latitude'] ?? json['lat']),
      longitude: _readDouble(json['longitude'] ?? json['lng'] ?? json['lon']),
      contactPerson: _readString(
        json['contact_person'] ??
            json['contactPerson'] ??
            json['contact_name'] ??
            json['contactName'],
      ),
      contactMobile: _readString(
        json['contact_mobile'] ??
            json['contactMobile'] ??
            json['contact_phone'] ??
            json['contactPhone'] ??
            json['mobile'] ??
            json['phone'],
      ),
    );
  }

  static String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }
}

class RtoDetails {
  const RtoDetails({
    this.amount,
    this.totalAmount,
    this.forwardAmount,
    this.returnAmount,
    this.baseAmount,
    this.dropLocation,
    this.dropAddress,
    this.status,
    this.rtoOtp,
    this.rtoNotes,
  });

  final double? amount;
  final double? totalAmount;
  final double? forwardAmount;
  final double? returnAmount;
  final double? baseAmount;
  final RtoDropLocation? dropLocation;
  final String? dropAddress;
  final String? status;
  final String? rtoOtp;
  final String? rtoNotes;

  /// Partner-facing total: prefer `total_amount`, then `amount`.
  double? get partnerTotalEarning {
    if (totalAmount != null && totalAmount! > 0) return totalAmount;
    if (amount != null && amount! > 0) return amount;
    return null;
  }

  String? get formattedTotalEarning {
    final value = partnerTotalEarning;
    if (value == null) return null;
    return value.toStringAsFixed(2);
  }

  String? get formattedForwardAmount {
    final value = forwardAmount;
    if (value == null || value <= 0) return null;
    return value.toStringAsFixed(2);
  }

  String? get formattedReturnAmount {
    final value = returnAmount;
    if (value == null || value <= 0) return null;
    return value.toStringAsFixed(2);
  }

  String? get formattedBaseAmount {
    final value = baseAmount;
    if (value == null || value <= 0) return null;
    return value.toStringAsFixed(2);
  }

  String? get returnDestinationAddress {
    final fromDrop = dropLocation?.displayAddress;
    if (fromDrop != null && fromDrop.isNotEmpty) return fromDrop;
    final fallback = dropAddress?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }

  String? get returnDestinationLabel {
    final hub = dropLocation?.hubName?.trim();
    final address = returnDestinationAddress;
    if (hub != null && hub.isNotEmpty && address != null && address.isNotEmpty) {
      if (address.toLowerCase().contains(hub.toLowerCase())) return address;
      return '$hub\n$address';
    }
    return address ?? hub;
  }

  factory RtoDetails.fromOrderJson(Map<String, dynamic> json) {
    final detailsMap = _asMap(json['rto_details'] ?? json['rtoDetails']);
    final dropFallback = _asMap(
      json['rto_drop_location'] ?? json['rtoDropLocation'],
    );

    RtoDropLocation? dropLocation;
    if (detailsMap != null) {
      final nested = _asMap(
        detailsMap['drop_location'] ??
            detailsMap['dropLocation'] ??
            detailsMap['hub'] ??
            detailsMap['iap'],
      );
      if (nested != null && nested.isNotEmpty) {
        dropLocation = RtoDropLocation.fromJson(nested);
      }
    }
    if ((dropLocation == null ||
            (dropLocation.displayAddress == null &&
                dropLocation.hubName == null)) &&
        dropFallback != null &&
        dropFallback.isNotEmpty) {
      dropLocation = RtoDropLocation.fromJson(dropFallback);
    }

    final rootAmount = _readDouble(json['rto_amount'] ?? json['rtoAmount']);

    if (detailsMap == null &&
        dropLocation == null &&
        rootAmount == null &&
        json['rto_otp'] == null &&
        json['rtoOtp'] == null &&
        json['rto_notes'] == null &&
        json['rtoNotes'] == null &&
        json['rto_status'] == null &&
        json['rtoStatus'] == null) {
      return const RtoDetails();
    }

    return RtoDetails(
      amount: _readDouble(detailsMap?['amount']) ?? rootAmount,
      totalAmount: _readDouble(
        detailsMap?['total_amount'] ?? detailsMap?['totalAmount'],
      ),
      forwardAmount: _readDouble(
        detailsMap?['forward_amount'] ?? detailsMap?['forwardAmount'],
      ),
      returnAmount: _readDouble(
        detailsMap?['return_amount'] ?? detailsMap?['returnAmount'],
      ),
      baseAmount: _readDouble(
        detailsMap?['base_amount'] ?? detailsMap?['baseAmount'],
      ),
      dropLocation: dropLocation,
      dropAddress: _readString(
        detailsMap?['drop_address'] ??
            detailsMap?['dropAddress'] ??
            json['rto_drop_address'] ??
            json['rtoDropAddress'],
      ),
      status: _readString(
        detailsMap?['status'] ??
            json['rto_status'] ??
            json['rtoStatus'],
      ),
      rtoOtp: _readString(
        detailsMap?['rto_otp'] ??
            detailsMap?['rtoOtp'] ??
            detailsMap?['otp'] ??
            json['rto_otp'] ??
            json['rtoOtp'],
      ),
      rtoNotes: _readString(
        detailsMap?['rto_notes'] ??
            detailsMap?['rtoNotes'] ??
            detailsMap?['notes'] ??
            json['rto_notes'] ??
            json['rtoNotes'],
      ),
    );
  }

  bool get hasAnyData =>
      partnerTotalEarning != null ||
      forwardAmount != null ||
      returnAmount != null ||
      dropLocation != null ||
      (dropAddress != null && dropAddress!.isNotEmpty) ||
      (status != null && status!.isNotEmpty) ||
      (rtoOtp != null && rtoOtp!.isNotEmpty) ||
      (rtoNotes != null && rtoNotes!.isNotEmpty);

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  static String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final cleaned = value.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return null;
    return double.tryParse(cleaned);
  }
}
