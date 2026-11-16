import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import 'duty_lock_service.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  static CartService get instance => _instance;

  CartService._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  int get totalItemCount {
    return _items.fold<int>(0, (sum, cartItem) => sum + cartItem.quantity);
  }

  double get subtotal {
    return _items.fold<double>(0.0, (sum, cartItem) => sum + cartItem.totalPrice);
  }

  /// Unique canteens present in the active cart
  Set<String> get activeCanteens {
    return _items.map((e) => e.item.canteen).toSet();
  }

  /// Primary canteen for delivery pickup (or first in list)
  String get primaryCanteen {
    if (_items.isEmpty) return 'Main Canteen';
    return _items.first.item.canteen;
  }

  /// Processing / Campus Delivery fee per canteen
  /// In CIT-U D-Dart, standard campus delivery fee defaults to activeConfig (₱20.00).
  /// If set to 0.0 for promotional zero-processing fee, it reflects ₱0.
  Map<String, double> get canteenProcessingFees {
    const allCanteens = ['Main Canteen', 'Elementary Canteen', 'College Canteen'];
    final baseFee = DutyLockService.activeConfig.standardDeliveryFee;
    final map = <String, double>{};

    for (final canteen in allCanteens) {
      if (activeCanteens.contains(canteen)) {
        map[canteen] = baseFee;
      } else {
        map[canteen] = 0.0;
      }
    }
    return map;
  }

  double get totalProcessingFee {
    if (_items.isEmpty) return 0.0;
    // Standard campus fee (₱20.00) or sum across distinct pickup canteens
    final distinctCount = activeCanteens.length;
    final baseFee = DutyLockService.activeConfig.standardDeliveryFee;
    return distinctCount > 0 ? (baseFee * distinctCount) : 0.0;
  }

  double get orderTotal => subtotal + totalProcessingFee;

  int getQuantity(String itemId) {
    final index = _items.indexWhere((ci) => ci.item.id == itemId);
    if (index == -1) return 0;
    return _items[index].quantity;
  }

  void addItem(CanteenMenuItem item, {int quantity = 1}) {
    if (quantity <= 0) return;
    final index = _items.indexWhere((ci) => ci.item.id == item.id);
    if (index != -1) {
      final existing = _items[index];
      _items[index] = existing.copyWith(quantity: existing.quantity + quantity);
    } else {
      _items.add(CartItem(item: item, quantity: quantity));
    }
    notifyListeners();
  }

  void updateQuantity(String itemId, int newQuantity) {
    final index = _items.indexWhere((ci) => ci.item.id == itemId);
    if (index == -1) return;

    if (newQuantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: newQuantity);
    }
    notifyListeners();
  }

  void incrementQuantity(String itemId) {
    final index = _items.indexWhere((ci) => ci.item.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(quantity: _items[index].quantity + 1);
      notifyListeners();
    }
  }

  void decrementQuantity(String itemId) {
    final index = _items.indexWhere((ci) => ci.item.id == itemId);
    if (index != -1) {
      final current = _items[index].quantity;
      if (current <= 1) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: current - 1);
      }
      notifyListeners();
    }
  }

  void removeItem(String itemId) {
    _items.removeWhere((ci) => ci.item.id == itemId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  /// Formats human-readable order summary for the runner gig board and Supabase
  String generateOrderDescription() {
    if (_items.isEmpty) return 'Campus errand request';
    return _items.map((ci) => '${ci.quantity}x ${ci.item.name}').join(', ');
  }

  /// Serialized cart items payload for storage
  List<Map<String, dynamic>> serializeItems() {
    return _items.map((ci) => ci.toJson()).toList();
  }
}
