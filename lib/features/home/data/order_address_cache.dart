import 'dart:convert';

import 'package:nomoride/features/home/data/models/dp_order.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The order list API can return a placeholder instead of the customer
/// address, but the socket broadcast carries the real one. Addresses are kept
/// per order (id and order number) so the home card can show them later.
class OrderAddressCache {
  OrderAddressCache._();

  static const _prefsKey = 'order_address_cache_v1';
  static const _maxEntries = 100;

  static Map<String, Map<String, String>>? _memory;

  static Future<Map<String, Map<String, String>>> _load() async {
    final memory = _memory;
    if (memory != null) return memory;

    final loaded = <String, Map<String, String>>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value is Map) {
              loaded[key.toString()] = value.map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              );
            }
          });
        }
      }
    } catch (_) {}
    return _memory = loaded;
  }

  static Future<void> remember({
    required String orderId,
    required String orderNumber,
    String? pickupAddress,
    String? deliveryAddress,
  }) async {
    final entry = <String, String>{
      if (!DpOrder.isDummyAddress(pickupAddress)) 'pickup': pickupAddress!.trim(),
      if (!DpOrder.isDummyAddress(deliveryAddress))
        'drop': deliveryAddress!.trim(),
    };
    if (entry.isEmpty) return;

    final cache = await _load();
    for (final key in [orderId.trim(), orderNumber.trim()]) {
      if (key.isEmpty) continue;
      cache.remove(key);
      cache[key] = entry;
    }
    while (cache.length > _maxEntries * 2) {
      cache.remove(cache.keys.first);
    }
    await _persist(cache);
  }

  /// Saves real customer addresses keyed by `customerAddressId`, so orders
  /// that only carry the placeholder can reuse one seen on another order.
  static Future<void> rememberCustomerAddresses(
    Map<String, String> byAddressId,
  ) async {
    if (byAddressId.isEmpty) return;
    final cache = await _load();
    var changed = false;
    byAddressId.forEach((addressId, address) {
      final key = 'addr:$addressId';
      if (cache[key]?['customer'] == address) return;
      cache.remove(key);
      cache[key] = {'customer': address};
      changed = true;
    });
    if (!changed) return;
    while (cache.length > _maxEntries * 2) {
      cache.remove(cache.keys.first);
    }
    await _persist(cache);
  }

  static Future<String?> customerAddressFor(String? addressId) async {
    final id = addressId?.trim();
    if (id == null || id.isEmpty) return null;
    final cache = await _load();
    return cache['addr:$id']?['customer'];
  }

  static Future<void> _persist(Map<String, Map<String, String>> cache) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(cache));
    } catch (_) {}
  }

  static Future<({String? pickup, String? drop})> lookup({
    String? orderId,
    String? orderNumber,
  }) async {
    final cache = await _load();
    for (final key in [orderId?.trim(), orderNumber?.trim()]) {
      if (key == null || key.isEmpty) continue;
      final entry = cache[key];
      if (entry != null) return (pickup: entry['pickup'], drop: entry['drop']);
    }
    return (pickup: null, drop: null);
  }
}
