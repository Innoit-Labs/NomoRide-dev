import 'dart:convert';
import 'package:flutter/foundation.dart';

class DpOrderGarment {
  const DpOrderGarment({
    this.name,
    this.size,
    this.quantity,
    this.imageUrl,
  });

  final String? name;
  final String? size;
  final int? quantity;
  final String? imageUrl;

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
  }) {
    return DpOrderGarment(
      name: name ?? this.name,
      size: size ?? this.size,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
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

  factory DpOrderGarment.fromJson(Map<String, dynamic> json) {
    return DpOrderGarment(
      name: _readString(
        json['name'] ??
            json['garment_name'] ??
            json['garmentName'] ??
            json['product_name'] ??
            json['productName'] ??
            json['title'] ??
            json['item_name'] ??
            json['itemName'],
      ),
      size: _readString(
        json['size'] ?? json['garment_size'] ?? json['garmentSize'],
      ),
      quantity: _readInt(json['quantity'] ?? json['qty'] ?? json['count']),
      imageUrl: _readImageUrl(json),
    );
  }

  static List<DpOrderGarment> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) {
          if (item is Map) {
            return DpOrderGarment.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            );
          }
          if (item is String) {
            final text = item.trim();
            if (text.isEmpty) return null;
            if (text.startsWith('http')) {
              return DpOrderGarment(imageUrl: text);
            }
            return DpOrderGarment(name: text);
          }
          return null;
        })
        .whereType<DpOrderGarment>()
        .where(
          (g) =>
              (g.name?.trim().isNotEmpty == true) ||
              (g.imageUrl?.trim().isNotEmpty == true),
        )
        .toList();
  }

  static String? _readImageUrl(Map<String, dynamic> json) {
    final candidates = [
      json['primary_image_url'],
      json['primaryImageUrl'],
      json['image'],
      json['image_url'],
      json['imageUrl'],
      json['thumbnail'],
      json['thumbnail_url'],
      json['thumbnailUrl'],
      json['url'],
      json['src'],
    ];
    for (final value in candidates) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text != 'null') return text;
    }
    final images = json['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map) {
        return _readImageUrl(
          first.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
      final text = first?.toString().trim();
      if (text != null && text.isNotEmpty && text != 'null') return text;
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
    this.durationDays,
    this.durationLabel,
    this.garmentCount,
    this.quantity,
    this.imageUrls = const [],
    this.garments = const [],
  });

  final String? name;
  final int? durationDays;
  final String? durationLabel;
  final int? garmentCount;
  final int? quantity;
  final List<String> imageUrls;
  final List<DpOrderGarment> garments;

  /// e.g. "1 Day Wardrobe Kit" when duration + name are available.
  String? get displayTitle {
    final productName = name?.trim();
    if (productName == null || productName.isEmpty) return null;

    final lower = productName.toLowerCase();
    final hasDayPrefix = RegExp(r'^\d+\s*day').hasMatch(lower);
    if (hasDayPrefix) return _titleCase(productName);

    if (durationDays != null && durationDays! > 0) {
      final dayWord = durationDays == 1 ? 'Day' : 'Days';
      return '${durationDays!} $dayWord ${_titleCase(productName)}';
    }

    final label = durationLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return '${_titleCase(label)} ${_titleCase(productName)}';
    }

    return _titleCase(productName);
  }

  String? get garmentCountLabel {
    final count = effectiveGarmentCount;
    if (count == null) return null;
    return 'No of Garments: $count';
  }

  int? get effectiveGarmentCount {
    if (garmentCount != null) return garmentCount;
    if (garments.isNotEmpty) return garments.length;
    if (imageUrls.length > 1) return imageUrls.length;
    return null;
  }

  /// Items shown in the expanded dropdown list (duplicates merged by qty).
  List<DpOrderGarment> get expandableItems {
    if (garments.isNotEmpty) {
      return DpOrderGarment.mergeDuplicates(garments);
    }
    if (imageUrls.length > 1) {
      return DpOrderGarment.mergeDuplicates([
        for (var i = 0; i < imageUrls.length; i++)
          DpOrderGarment(
            name: 'Garment ${i + 1}',
            imageUrl: imageUrls[i],
            quantity: 1,
          ),
      ]);
    }
    return const [];
  }

  bool get canExpand => expandableItems.isNotEmpty;

  factory DpOrderProduct.fromJson(Map<String, dynamic> json) {
    final durationRaw = json['duration_days'] ??
        json['durationDays'] ??
        json['rental_days'] ??
        json['rentalDays'] ??
        json['days'] ??
        json['duration'];

    final imageUrls = _readImageUrls(json);
    final garments = _readGarments(json);

    return DpOrderProduct(
      name: _readString(
        json['name'] ??
            json['product_name'] ??
            json['productName'] ??
            json['title'] ??
            json['package_type'] ??
            json['packageType'] ??
            json['item_name'] ??
            json['itemName'],
      ),
      durationDays: _readInt(durationRaw),
      durationLabel: _readDurationLabel(durationRaw, json),
      garmentCount: _readInt(
        json['garment_count'] ??
            json['garmentCount'] ??
            json['no_of_garments'] ??
            json['noOfGarments'] ??
            json['garments_count'] ??
            json['garmentsCount'] ??
            json['total_garments'] ??
            json['totalGarments'],
      ),
      quantity: _readInt(
        json['quantity'] ?? json['qty'] ?? json['count'],
      ),
      imageUrls: imageUrls,
      garments: garments,
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
            product.imageUrls.isNotEmpty ||
            product.garments.isNotEmpty ||
            product.garmentCount != null ||
            product.durationDays != null)
        .toList();
  }

  static List<DpOrderGarment> _readGarments(Map<String, dynamic> json) {
    var kitDetailsRaw = json['kitDetails'] ?? json['kit_details'];
    if (kitDetailsRaw != null) {
      debugPrint('[ORDER DEBUG] kitDetails found');
      Map<String, dynamic>? kitDetailsMap;
      if (kitDetailsRaw is Map) {
        kitDetailsMap = kitDetailsRaw.map((k, v) => MapEntry(k.toString(), v));
      } else if (kitDetailsRaw is String) {
        try {
          final decoded = jsonDecode(kitDetailsRaw);
          if (decoded is Map) {
            kitDetailsMap = decoded.map((k, v) => MapEntry(k.toString(), v));
          }
        } catch (_) {}
      }

      if (kitDetailsMap != null) {
        var selectedItemsRaw = kitDetailsMap['selectedItems'] ?? kitDetailsMap['selected_items'];
        if (selectedItemsRaw != null) {
          List? selectedList;
          if (selectedItemsRaw is List) {
            selectedList = selectedItemsRaw;
          } else if (selectedItemsRaw is String) {
            try {
              final decoded = jsonDecode(selectedItemsRaw);
              if (decoded is List) {
                selectedList = decoded;
              }
            } catch (_) {}
          }

          if (selectedList != null && selectedList.isNotEmpty) {
            debugPrint('[ORDER DEBUG] selectedItems count: ${selectedList.length}');
            final List<DpOrderGarment> list = [];
            for (final item in selectedList) {
              if (item is Map) {
                final garmentMap = item.map((k, v) => MapEntry(k.toString(), v));
                final g = DpOrderGarment.fromJson(garmentMap);
                if (g.name != null && g.name!.isNotEmpty) {
                  debugPrint('[ORDER DEBUG] Mapping garment: ${g.name}');
                  list.add(g);
                }
              }
            }
            if (list.isNotEmpty) {
              return list;
            }
          }
        }
      }
    }

    final candidates = [
      json['garments'],
      json['garment_list'],
      json['garmentList'],
      json['items'],
      json['product_items'],
      json['productItems'],
      json['line_items'],
      json['lineItems'],
      json['variants'],
    ];

    for (final candidate in candidates) {
      final list = DpOrderGarment.listFromJson(candidate);
      if (list.isNotEmpty) return list;
    }
    return const [];
  }

  static String? _readDurationLabel(
    dynamic durationRaw,
    Map<String, dynamic> json,
  ) {
    final labeled = _readString(
      json['duration_label'] ??
          json['durationLabel'] ??
          json['rental_duration'] ??
          json['rentalDuration'],
    );
    if (labeled != null) return labeled;

    if (durationRaw is String) {
      final text = durationRaw.trim();
      if (text.isEmpty) return null;
      if (int.tryParse(text) != null) return null;
      return text;
    }
    return null;
  }

  static List<String> _readImageUrls(Map<String, dynamic> json) {
    final urls = <String>[];

    void add(dynamic value) {
      if (value == null) return;
      if (value is List) {
        for (final item in value) {
          add(item);
        }
        return;
      }
      if (value is Map) {
        add(
          value['url'] ??
              value['image'] ??
              value['image_url'] ??
              value['imageUrl'] ??
              value['src'],
        );
        return;
      }
      final text = value.toString().trim();
      if (text.isEmpty || text == 'null') return;
      if (!urls.contains(text)) urls.add(text);
    }

    add(json['images']);
    add(json['image_urls']);
    add(json['imageUrls']);
    add(json['product_images']);
    add(json['productImages']);
    add(json['garment_images']);
    add(json['garmentImages']);
    add(json['image']);
    add(json['image_url']);
    add(json['imageUrl']);
    add(json['thumbnail']);
    add(json['thumbnail_url']);
    add(json['thumbnailUrl']);

    return urls;
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
