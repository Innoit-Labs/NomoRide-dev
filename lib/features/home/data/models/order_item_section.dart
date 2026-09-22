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
        return 'Subscription';
      case OrderItemSectionType.nonSubscription:
        return 'Non-Subscription';
      case OrderItemSectionType.kidsEssentials:
        return 'Kids & Essentials';
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
      count += product.effectiveGarmentCount ?? 1;
    }
    return count;
  }

  String get itemsLabel => itemCount == 1 ? '1 Item' : '$itemCount Items';
}

class OrderItemClassifier {
  const OrderItemClassifier._();

  static OrderItemSectionType classify(
    Map<String, dynamic> json, [
    Map<String, dynamic>? kitDetails,
  ]) {
    final itemType = _normalizeKey(json['itemType']);
    final cartSection = _normalizeKey(json['cart_section']);
    final categoryName = _normalizeKey(json['categoryName']);

    if (_isKidsEssentials(itemType, cartSection, categoryName)) {
      return OrderItemSectionType.kidsEssentials;
    }

    if (itemType == 'subscription' || cartSection == 'subscription') {
      return OrderItemSectionType.subscription;
    }

    if (itemType == 'non_subscription' || cartSection == 'non_subscription') {
      return OrderItemSectionType.nonSubscription;
    }

    return OrderItemSectionType.nonSubscription;
  }

  static bool _isKidsEssentials(
    String? itemType,
    String? cartSection,
    String? categoryName,
  ) {
    const keys = {
      'kids_essentials',
      'kids_and_essentials',
      'kids_&_essentials',
      'kids_essential',
      'essential_wear',
      'kids_wear',
      'essential',
      'essentials',
    };

    if (itemType != null && keys.contains(itemType)) return true;
    if (cartSection != null && keys.contains(cartSection)) return true;

    if (categoryName != null) {
      if (categoryName.contains('kids') && categoryName.contains('essential')) {
        return true;
      }
      if (categoryName == 'kids_wear' ||
          categoryName == 'essential_wear' ||
          categoryName == 'kids & essentials') {
        return true;
      }
    }

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
