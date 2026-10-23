import 'dart:convert';

import 'package:nomoride/features/home/data/models/order_item_section.dart';

class DpOrderGarment {
  const DpOrderGarment({
    this.name,
    this.size,
    this.quantity,
    this.imageUrl,
    this.qrCode,
    this.price,
    this.isNonReturnable = false,
  });

  final String? name;
  final String? size;
  final int? quantity;
  final String? imageUrl;
  final String? qrCode;
  final String? price;
  final bool isNonReturnable;

  String get displayName {
    final text = name?.trim();
    if (text != null && text.isNotEmpty) return _titleCase(text);
    return 'Garment';
  }

  String? get detailLabel {
    final parts = <String>[];
    final sizeText = size?.trim();
    if (sizeText != null && sizeText.isNotEmpty) {
      parts.add('Size: ${sizeText.toUpperCase()}');
    }
    if (quantity != null && quantity! > 0) parts.add('Qty: $quantity');
    final priceText = price?.trim();
    if (priceText != null && priceText.isNotEmpty) {
      parts.add(priceText.startsWith('₹') ? priceText : '₹$priceText');
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String get _mergeKey {
    final nameKey = displayName.toLowerCase().trim();
    final sizeKey = (size ?? '').trim().toLowerCase();
    final qrKey = (qrCode ?? '').trim().toLowerCase();
    return '$nameKey|$sizeKey|$qrKey';
  }

  DpOrderGarment copyWith({
    String? name,
    String? size,
    int? quantity,
    String? imageUrl,
    String? qrCode,
    String? price,
    bool? isNonReturnable,
  }) {
    return DpOrderGarment(
      name: name ?? this.name,
      size: size ?? this.size,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      qrCode: qrCode ?? this.qrCode,
      price: price ?? this.price,
      isNonReturnable: isNonReturnable ?? this.isNonReturnable,
    );
  }

  /// Groups identical garments (same name + size + QR) and sums quantity.
  static List<DpOrderGarment> mergeDuplicates(List<DpOrderGarment> items) {
    if (items.isEmpty) return const [];

    final merged = <String, DpOrderGarment>{};
    final order = <String>[];

    for (final item in items) {
      final key = item._mergeKey;
      final existing = merged[key];
      if (existing == null) {
        order.add(key);
        merged[key] = item.copyWith(
          quantity: item.quantity != null && item.quantity! > 0
              ? item.quantity
              : 1,
        );
        continue;
      }

      final existingQty =
          existing.quantity != null && existing.quantity! > 0
              ? existing.quantity!
              : 1;
      final addQty =
          item.quantity != null && item.quantity! > 0 ? item.quantity! : 1;

      merged[key] = existing.copyWith(
        quantity: existingQty + addQty,
        imageUrl: existing.imageUrl?.trim().isNotEmpty == true
            ? existing.imageUrl
            : item.imageUrl,
        qrCode: existing.qrCode?.trim().isNotEmpty == true
            ? existing.qrCode
            : item.qrCode,
        price: existing.price?.trim().isNotEmpty == true
            ? existing.price
            : item.price,
      );
    }

    return [for (final key in order) merged[key]!];
  }

  /// Sum of garment quantities (merged by name + size).
  static int totalQuantity(Iterable<DpOrderGarment> items) {
    var total = 0;
    for (final item in items) {
      final qty = item.quantity;
      total += (qty != null && qty > 0) ? qty : 1;
    }
    return total;
  }

  factory DpOrderGarment.fromJson(Map<String, dynamic> json) {
    return DpOrderGarment(
      name: _readLabel(
        json['product_name'] ??
            json['productName'] ??
            json['name'] ??
            json['garment_name'] ??
            json['garmentName'],
      ),
      size: _readLabel(json['size'] ?? json['variant_size'] ?? json['variantSize']),
      quantity: _readInt(json['quantity'] ?? json['qty']),
      imageUrl: _readUrl(
        json['primary_image_url'] ??
            json['primaryImageUrl'] ??
            json['image_url'] ??
            json['imageUrl'] ??
            json['product_image'] ??
            json['productImage'] ??
            json['image'],
      ),
      qrCode: _readRaw(
        json['qr_code'] ??
            json['qrCode'] ??
            (json['qr_codes'] is List && (json['qr_codes'] as List).isNotEmpty
                ? (json['qr_codes'] as List).first
                : null) ??
            (json['qrCodes'] is List && (json['qrCodes'] as List).isNotEmpty
                ? (json['qrCodes'] as List).first
                : null),
      ),
      price: _readPrice(
        json['price'] ??
            json['unitPrice'] ??
            json['unit_price'] ??
            json['current_amount'] ??
            json['currentAmount'],
      ),
    );
  }

  static List<DpOrderGarment> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => DpOrderGarment.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((g) => g.name?.trim().isNotEmpty == true)
        .toList();
  }

  static String? _readRaw(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }

  static String? _readLabel(dynamic value) {
    final text = _readRaw(value);
    if (text == null) return null;
    return text.replaceAll('_', ' ');
  }

  static String? _readUrl(dynamic value) {
    return _readRaw(value);
  }

  static String? _readPrice(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final n = value.toDouble();
      if (n <= 0) return null;
      return n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2);
    }
    final text = _readRaw(value);
    if (text == null) return null;
    final cleaned = text.replaceAll(RegExp(r'[^\d.]'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed <= 0) return null;
    return parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toStringAsFixed(2);
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static String _titleCase(String value) {
    return value
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class DpOrderProduct {
  const DpOrderProduct({
    this.name,
    this.kitType,
    this.quantity,
    this.garments = const [],
    this.sectionType,
    this.imageUrl,
    this.size,
  });

  final String? name;
  final String? kitType;
  final int? quantity;
  final List<DpOrderGarment> garments;
  final OrderItemSectionType? sectionType;
  final String? imageUrl;
  final String? size;

  bool get isKidsEssentialsSection =>
      sectionType == OrderItemSectionType.kidsEssentials;

  /// Wardrobe kit header from `kitDetails.kit_type` / `kit_name`.
  String? get displayTitle {
    final kitTypeLabel = kitType?.trim();
    if (kitTypeLabel != null && kitTypeLabel.isNotEmpty) {
      return kitTypeLabel;
    }

    // Prefer the selected garment name when there is no kit header.
    if (garments.length == 1) {
      return garments.first.displayName;
    }

    final productName = name?.trim();
    if (productName == null || productName.isEmpty) return null;
    return productName;
  }

  String? get garmentCountLabel {
    if (garments.length > 1) {
      final count = effectiveGarmentCount ?? garments.length;
      return 'No of Garments: $count';
    }
    if (garments.length == 1) {
      final g = garments.first;
      final parts = <String>[];
      final name = g.displayName;
      if (kitType != null &&
          kitType!.trim().isNotEmpty &&
          name.toLowerCase() != kitType!.trim().toLowerCase()) {
        parts.add(name);
      }
      if (g.size != null && g.size!.isNotEmpty) {
        parts.add('Size: ${g.size!.toUpperCase()}');
      }
      parts.add('Qty: ${g.quantity ?? quantity ?? 1}');
      return parts.join(' · ');
    }
    final q = quantity ?? 1;
    return 'Qty: $q';
  }

  int? get effectiveGarmentCount {
    final items = expandableItems;
    if (items.isEmpty) return null;
    final total = DpOrderGarment.totalQuantity(items);
    return total > 0 ? total : null;
  }

  /// Items shown from `kitDetails.selectedItems`.
  List<DpOrderGarment> get expandableItems {
    if (garments.isEmpty) return const [];
    return DpOrderGarment.mergeDuplicates(garments);
  }

  /// Always let the partner open selectedItems when present.
  bool get canExpand => expandableItems.isNotEmpty;

  /// Images for the kit header thumbnail grid (selectedItems images first).
  List<String> get previewImageUrls {
    final urls = <String>[];

    for (final garment in garments) {
      final text = garment.imageUrl?.trim();
      if (text == null || text.isEmpty) continue;
      if (!urls.contains(text)) urls.add(text);
      if (urls.length >= 4) break;
    }

    if (urls.isEmpty) {
      final fallback = imageUrl?.trim();
      if (fallback != null && fallback.isNotEmpty) {
        urls.add(fallback);
      }
    }

    return urls;
  }

  bool get showPreviewGrid =>
      previewImageUrls.length > 1 || garments.length > 1;

  factory DpOrderProduct.fromJson(Map<String, dynamic> json) {
    final kitDetails = _parseKitDetailsMap(json);
    final sectionType = OrderItemClassifier.classify(json, kitDetails);
    var garments = _readGarments(kitDetails);

    final imageUrl = _readUrl(
      json['imageUrl'] ??
          json['image'] ??
          json['primary_image_url'] ??
          json['primaryImageUrl'] ??
          json['product_image'] ??
          json['productImage'] ??
          json['image_url'],
    );
    final size = _readLabel(json['size']);
    final qty = _readInt(json['quantity']) ?? 1;
    final productName = _readLabel(json['productName'] ?? json['product_name']);

    if (garments.isEmpty && productName != null && productName.isNotEmpty) {
      garments = [
        DpOrderGarment(
          name: productName,
          size: size,
          quantity: qty,
          imageUrl: imageUrl,
          isNonReturnable: sectionType == OrderItemSectionType.kidsEssentials,
        ),
      ];
    } else if (sectionType == OrderItemSectionType.kidsEssentials) {
      garments = [
        for (final garment in garments)
          garment.copyWith(isNonReturnable: true),
      ];
    }

    return DpOrderProduct(
      name: productName,
      kitType: _readLabel(
        kitDetails?['kit_type'] ??
            kitDetails?['kitType'] ??
            kitDetails?['kit_name'] ??
            kitDetails?['kitName'],
      ),
      quantity: qty,
      garments: garments,
      sectionType: sectionType,
      imageUrl: imageUrl,
      size: size,
    );
  }

  static List<DpOrderProduct> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => DpOrderProduct.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .where((product) =>
            (product.name?.trim().isNotEmpty == true) ||
            (product.kitType?.trim().isNotEmpty == true) ||
            product.garments.isNotEmpty)
        .toList();
  }

  static List<DpOrderGarment> _readGarments(Map<String, dynamic>? kitDetails) {
    if (kitDetails == null) return const [];

    final selectedItemsRaw = kitDetails['selectedItems'] ??
        kitDetails['selected_items'] ??
        kitDetails['garments'] ??
        kitDetails['items'];
    if (selectedItemsRaw is! List || selectedItemsRaw.isEmpty) {
      return const [];
    }

    final garments = <DpOrderGarment>[];
    for (final item in selectedItemsRaw) {
      if (item is! Map) continue;
      final garment = DpOrderGarment.fromJson(
        item.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (garment.name?.trim().isNotEmpty == true) {
        garments.add(garment);
      }
    }
    return garments;
  }

  static Map<String, dynamic>? _parseKitDetailsMap(Map<String, dynamic> json) {
    final raw = json['kitDetails'] ?? json['kit_details'] ?? json['kit'];
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {}
    }
    return null;
  }

  static String? _readLabel(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text.replaceAll('_', ' ');
  }

  static String? _readUrl(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final asInt = int.tryParse(text);
    if (asInt != null) return asInt;
    final match = RegExp(r'(\d+)').firstMatch(text);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }
}
