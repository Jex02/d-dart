import 'package:flutter/foundation.dart';
import '../models/campus_location.dart';
import '../models/cart_item.dart';
import '../models/system_config.dart';
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
    const allCanteens = CampusLocation.officialCanteens;
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

  /// Distance in meters from the primary pickup canteen to the given delivery destination.
  double? getDistanceTo(String destination) {
    return CampusLocation.getDistanceMeters(primaryCanteen, destination);
  }

  /// Distance in meters from a specific pickup canteen to the given delivery destination.
  double? getDistanceForCanteen(String canteen, String destination) {
    return CampusLocation.getDistanceMeters(canteen, destination);
  }

  /// Map of each active canteen to its distance in meters to the given delivery destination.
  Map<String, double?> getDistancesForDestination(String destination) {
    final map = <String, double?>{};
    for (final canteen in activeCanteens) {
      map[canteen] = CampusLocation.getDistanceMeters(canteen, destination);
    }
    return map;
  }

  /// Calculates the delivery fee per active canteen for the chosen destination.
  /// If a distance is missing for a canteen, its fee is null.
  Map<String, double?> getDeliveryFeesForDestination(
    String destination, {
    SystemConfig? config,
  }) {
    final cfg = config ?? DutyLockService.activeConfig;
    final map = <String, double?>{};
    for (final canteen in activeCanteens) {
      map[canteen] = CampusLocation.calculateDeliveryFee(
        canteen: canteen,
        destination: destination,
        config: cfg,
      );
    }
    return map;
  }

  /// Calculates total delivery fee across all distinct active canteens to the given destination.
  /// If any active canteen cannot reach the destination (missing distance), returns null to prevent checkout.
  double? calculateDeliveryFeeTo(
    String destination, {
    SystemConfig? config,
  }) {
    if (_items.isEmpty) return 0.0;
    final fees = getDeliveryFeesForDestination(destination, config: config);
    double total = 0.0;
    for (final fee in fees.values) {
      if (fee == null) return null;
      total += fee;
    }
    return total;
  }

  /// Total order amount including distance-based delivery fees for the specified destination.
  double? calculateOrderTotal(
    String destination, {
    SystemConfig? config,
  }) {
    final fee = calculateDeliveryFeeTo(destination, config: config);
    if (fee == null) return null;
    return subtotal + fee;
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
