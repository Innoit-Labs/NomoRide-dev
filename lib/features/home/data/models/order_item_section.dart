import 'package:nomoride/features/home/data/models/dp_order_product.dart';

enum OrderItemSectionType {
  subscription,
  nonSubscription,
  kidsEssentials,
}

extension OrderItemSectionTypeX on OrderItemSectionType {
  String get title {
    switch (this) {
      case OrderItemSectionType.subscription:
        return 'Subscription Items';
      case OrderItemSectionType.nonSubscription:
        return 'Non-Subscription Items';
      case OrderItemSectionType.kidsEssentials:
        return 'Kids Items';
    }
  }
}

class OrderProductSection {
  const OrderProductSection({
    required this.type,
    required this.products,
  });

  final OrderItemSectionType type;
  final List<DpOrderProduct> products;

  String get title => type.title;

  int get itemCount {
    var count = 0;
    for (final product in products) {
      count += product.effectiveGarmentCount ?? product.quantity ?? 1;
    }
    return count;
  }

  String get itemsLabel {
    final count = itemCount;
    if (type == OrderItemSectionType.subscription ||
        type == OrderItemSectionType.nonSubscription) {
      return count == 1 ? '1 Garment' : '$count Garments';
    }
    return count == 1 ? '1 Item' : '$count Items';
  }
}

class OrderItemClassifier {
  const OrderItemClassifier._();

  static OrderItemSectionType classify(
    Map<String, dynamic> json, [
    Map<String, dynamic>? kitDetails,
  ]) {
    final itemType = _normalizeKey(json['itemType'] ?? json['item_type']);
    final cartSection = _normalizeKey(json['cart_section'] ?? json['cartSection']);
    final categoryName = _normalizeKey(json['categoryName'] ?? json['category_name']);
    final productName = _normalizeKey(json['productName'] ?? json['product_name']);

    if (_isKidsEssentials(itemType, cartSection, categoryName, productName)) {
      return OrderItemSectionType.kidsEssentials;
    }

    if (itemType == 'subscription' || cartSection == 'subscription') {
      return OrderItemSectionType.subscription;
    }

    if (itemType == 'non_subscription' ||
        cartSection == 'non_subscription' ||
        itemType == 'nonsubscription' ||
        cartSection == 'nonsubscription') {
      return OrderItemSectionType.nonSubscription;
    }

    if (kitDetails != null) {
      final kitNonSub = kitDetails['non_subscription'];
      final kitCartSection =
          _normalizeKey(kitDetails['cart_section'] ?? kitDetails['cartSection']);
      if (kitNonSub == true ||
          kitCartSection == 'non_subscription' ||
          kitCartSection == 'nonsubscription') {
        return OrderItemSectionType.nonSubscription;
      }
      if (kitNonSub == false || kitCartSection == 'subscription') {
        return OrderItemSectionType.subscription;
      }
    }

    return OrderItemSectionType.nonSubscription;
  }

  static bool _isKidsEssentials(
    String? itemType,
    String? cartSection,
    String? categoryName,
    String? productName,
  ) {
    bool hasKid(String? val) {
      if (val == null) return false;
      return val == 'kids' ||
          val.contains('kid') ||
          val.contains('child') ||
          val.contains('baby') ||
          val.contains('essential');
    }

    if (hasKid(itemType)) return true;
    if (hasKid(cartSection)) return true;
    if (hasKid(categoryName)) return true;
    if (hasKid(productName)) return true;

    return false;
  }

  static String? _normalizeKey(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty || text == 'null') return null;
    return text.replaceAll(RegExp(r'[\s-]+'), '_');
  }
}

class OrderProductSectionBuilder {
  const OrderProductSectionBuilder._();

  static const _displayOrder = [
    OrderItemSectionType.subscription,
    OrderItemSectionType.nonSubscription,
    OrderItemSectionType.kidsEssentials,
  ];

  static List<OrderProductSection> build(List<DpOrderProduct> products) {
    if (products.isEmpty) return const [];

    final grouped = <OrderItemSectionType, List<DpOrderProduct>>{};
    for (final product in products) {
      final type =
          product.sectionType ?? OrderItemSectionType.nonSubscription;
      grouped.putIfAbsent(type, () => []).add(product);
    }

    return [
      for (final type in _displayOrder)
        if ((grouped[type] ?? const []).isNotEmpty)
          OrderProductSection(
            type: type,
            products: grouped[type]!,
          ),
    ];
  }
}
