class CanteenMenuItem {
  final String id;
  final String name;
  final String canteen;
  final String category;
  final double price;
  final String unitDescription;
  final String? imageUrl;
  final bool isAvailable;
  final List<String> availableCanteens;

  const CanteenMenuItem({
    required this.id,
    required this.name,
    required this.canteen,
    required this.category,
    required this.price,
    required this.unitDescription,
    this.imageUrl,
    this.isAvailable = true,
    List<String>? availableCanteens,
  }) : availableCanteens = availableCanteens ?? const [];

  List<String> get canteensList {
    if (availableCanteens.isNotEmpty) return availableCanteens;
    return [canteen];
  }

  CanteenMenuItem copyWith({
    String? id,
    String? name,
    String? canteen,
    String? category,
    double? price,
    String? unitDescription,
    String? imageUrl,
    bool? isAvailable,
    List<String>? availableCanteens,
  }) {
    return CanteenMenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      canteen: canteen ?? this.canteen,
      category: category ?? this.category,
      price: price ?? this.price,
      unitDescription: unitDescription ?? this.unitDescription,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      availableCanteens: availableCanteens ?? this.availableCanteens,
    );
  }

  factory CanteenMenuItem.fromJson(Map<String, dynamic> json) {
    return CanteenMenuItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      canteen: json['canteen'] as String? ?? 'Main Canteen',
      category: json['category'] as String? ?? 'Food & snacks',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      unitDescription: json['unit_description'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      availableCanteens: (json['available_canteens'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'canteen': canteen,
      'category': category,
      'price': price,
      'unit_description': unitDescription,
      'image_url': imageUrl,
      'is_available': isAvailable,
      'available_canteens': availableCanteens,
    };
  }
}

class CartItem {
  final CanteenMenuItem item;
  final int quantity;

  const CartItem({
    required this.item,
    this.quantity = 1,
  });

  double get totalPrice => item.price * quantity;

  CartItem copyWith({
    CanteenMenuItem? item,
    int? quantity,
  }) {
    return CartItem(
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      item: CanteenMenuItem.fromJson(
        Map<String, dynamic>.from(json['item'] as Map? ?? {}),
      ),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item': item.toJson(),
      'quantity': quantity,
      'line_total': totalPrice,
    };
  }
}
