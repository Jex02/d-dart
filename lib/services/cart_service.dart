import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campus_location.dart';
import '../models/cart_item.dart';
import '../models/system_config.dart';
import 'duty_lock_service.dart';
import 'supabase_service.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  static CartService get instance => _instance;

  CartService._internal();

  final List<CartItem> _items = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
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

  // =========================================================================
  // PERSISTENCE & MULTI-PLATFORM SYNCHRONIZATION (Task 2)
  // =========================================================================

  String _storageKey([String? userId]) {
    final uid = userId ?? SupabaseService().currentUser?.id;
    return uid != null ? 'ddart_cart_user_$uid' : 'ddart_cart_local';
  }

  /// Restores cart from persistent local storage (SharedPreferences) and Supabase database.
  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = SupabaseService().currentUser?.id;
      final key = _storageKey(currentUserId);

      // 1. Try local storage first for fast response
      final localJson = prefs.getString(key);
      List<CartItem> restoredItems = [];

      if (localJson != null && localJson.isNotEmpty) {
        try {
          final List decoded = jsonDecode(localJson);
          restoredItems = decoded
              .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        } catch (e) {
          debugPrint('Error decoding local cart: $e');
        }
      }

      // If user is authenticated, sync with remote Supabase database
      if (currentUserId != null && SupabaseService().isAuthenticated) {
        try {
          final client = SupabaseService().client;
          final response = await client
              .from('customer_carts')
              .select('items, updated_at')
              .eq('user_id', currentUserId)
              .maybeSingle();

          if (response != null && response['items'] != null) {
            final List remoteItemsJson = response['items'] as List;
            final remoteItems = remoteItemsJson
                .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();

            // If remote has saved cart items, adopt them
            if (remoteItems.isNotEmpty) {
              restoredItems = remoteItems;
              await prefs.setString(key, jsonEncode(serializeItemsFrom(restoredItems)));
            } else if (restoredItems.isNotEmpty) {
              // Remote is empty but local has items: sync local up to Supabase
              await client.from('customer_carts').upsert({
                'user_id': currentUserId,
                'items': serializeItemsFrom(restoredItems),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              });
            }
          } else if (restoredItems.isNotEmpty) {
            // No row exists in customer_carts yet: create it with local items
            await client.from('customer_carts').upsert({
              'user_id': currentUserId,
              'items': serializeItemsFrom(restoredItems),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            });
          }
        } catch (e) {
          debugPrint('Supabase cart sync error: $e');
        }
      }

      _items.clear();
      _items.addAll(restoredItems);
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load persisted cart: $e');
    }
  }

  /// Automatically persists current cart to SharedPreferences and Supabase.
  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = SupabaseService().currentUser?.id;
      final key = _storageKey(currentUserId);
      final serialized = serializeItems();

      // Always save locally (works on web and mobile)
      await prefs.setString(key, jsonEncode(serialized));

      // If user is authenticated, sync to Supabase customer_carts table
      if (currentUserId != null && SupabaseService().isAuthenticated) {
        try {
          await SupabaseService().client.from('customer_carts').upsert({
            'user_id': currentUserId,
            'items': serialized,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Could not persist cart to Supabase: $e');
        }
      }
    } catch (e) {
      if (kDebugMode && !e.toString().contains('Binding has not yet been initialized')) {
        debugPrint('Error saving cart: $e');
      }
    }
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
    _saveCart();
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
    _saveCart();
  }

  void incrementQuantity(String itemId) {
    final index = _items.indexWhere((ci) => ci.item.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(quantity: _items[index].quantity + 1);
      notifyListeners();
      _saveCart();
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
      _saveCart();
    }
  }

  void removeItem(String itemId) {
    _items.removeWhere((ci) => ci.item.id == itemId);
    notifyListeners();
    _saveCart();
  }

  /// Clears cart. If [isSignOut] is true, only clears memory so user's remote cart
  /// is restored when they log back into their account.
  void clearCart({bool isSignOut = false}) {
    _items.clear();
    notifyListeners();

    if (isSignOut) {
      // Don't erase their remote saved cart on sign out
      return;
    }

    _saveCart();
  }

  /// Formats human-readable order summary for the runner gig board and Supabase
  String generateOrderDescription() {
    if (_items.isEmpty) return 'Campus errand request';
    return _items.map((ci) => '${ci.quantity}x ${ci.item.name}').join(', ');
  }

  /// Serialized cart items payload for storage
  List<Map<String, dynamic>> serializeItems() {
    return serializeItemsFrom(_items);
  }

  static List<Map<String, dynamic>> serializeItemsFrom(List<CartItem> items) {
    return items.map((ci) => ci.toJson()).toList();
  }
}
