import 'dart:convert';

import 'package:nomoride/features/home/data/models/order_item_section.dart';

class DpOrderGarment {  const DpOrderGarment({
    this.name,
    this.size,
    this.quantity,
    this.imageUrl,
    this.isNonReturnable = false,
  });

  final String? name;
  final String? size;
  final int? quantity;
  final String? imageUrl;
  final bool isNonReturnable;

  String get displayName {
    final text = name?.trim();
    if (text != null && text.isNotEmpty) return _titleCase(text);
    return 'Garment';
  }

  String? get detailLabel {
    final parts = <String>[];
    final sizeText = size?.trim();
    if (sizeText != null && sizeText.isNotEmpty) parts.add(sizeText);
    if (quantity != null && quantity! > 0) parts.add('Qty: $quantity');
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String get _mergeKey {
    final nameKey = displayName.toLowerCase().trim();
    final sizeKey = (size ?? '').trim().toLowerCase();
    return '$nameKey|$sizeKey';
  }

  DpOrderGarment copyWith({
    String? name,
    String? size,
    int? quantity,
    String? imageUrl,
    bool? isNonReturnable,
  }) {
    return DpOrderGarment(
      name: name ?? this.name,
      size: size ?? this.size,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      isNonReturnable: isNonReturnable ?? this.isNonReturnable,
    );
  }

  /// Groups identical garments (same name + size) and sums quantity.
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
      name: _readString(json['product_name']),
      size: _readString(json['size']),
      quantity: _readInt(json['quantity']),
      imageUrl: _readString(json['primary_image_url']),
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

  static String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text.replaceAll('_', ' ');
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

  /// Wardrobe kit header from `kitDetails.kit_type`; otherwise `productName`.
  String? get displayTitle {
    final kitTypeLabel = kitType?.trim();
    if (kitTypeLabel != null && kitTypeLabel.isNotEmpty) {
      return kitTypeLabel;
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
      if (g.size != null && g.size!.isNotEmpty) parts.add('Size: ${g.size}');
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

  /// Items shown in the expanded dropdown list (duplicates merged by qty).
  List<DpOrderGarment> get expandableItems {
    if (garments.isEmpty) return const [];
    return DpOrderGarment.mergeDuplicates(garments);
  }

  bool get canExpand => expandableItems.length > 1;

  /// Images for the kit header thumbnail grid (garment images first, up to 4).
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

    final imageUrl = _readString(
      json['imageUrl'] ??
          json['image'] ??
          json['primary_image_url'] ??
          json['product_image'],
    );
    final size = _readString(json['size']);
    final qty = _readInt(json['quantity']) ?? 1;
    final productName = _readString(json['productName'] ?? json['product_name']);

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
      kitType: _readString(kitDetails?['kit_type']),
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

    final selectedItemsRaw = kitDetails['selectedItems'];
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
    final raw = json['kitDetails'];
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

  static String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text.replaceAll('_', ' ');
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
