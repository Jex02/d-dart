import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/models/cart_item.dart';
import 'package:sd2/services/cart_service.dart';

void main() {
  const siomai = CanteenMenuItem(
    id: 'food-siomai',
    name: 'Pork Siomai with rice',
    canteen: 'Main Canteen',
    category: 'Food and snacks',
    price: 30.00,
    unitDescription: '3 for 30 Pesos',
    availableCanteens: ['Main Canteen', 'College Canteen'],
  );

  const mountainDew = CanteenMenuItem(
    id: 'bev-dew',
    name: 'Mountain dew (Plastic bottle)',
    canteen: 'Main Canteen',
    category: 'Beverages',
    price: 25.00,
    unitDescription: '25 Pesos/bottle',
    availableCanteens: ['Main Canteen', 'College Canteen', 'Elementary Canteen'],
  );

  const banana = CanteenMenuItem(
    id: 'des-banana',
    name: 'Banana',
    canteen: 'Main Canteen',
    category: 'Desserts',
    price: 15.00,
    unitDescription: '15 pesos/fruit',
    availableCanteens: ['Main Canteen', 'College Canteen', 'Elementary Canteen'],
  );

  const hotdog = CanteenMenuItem(
    id: 'food-hotdog',
    name: 'Hotdog',
    canteen: 'Main Canteen',
    category: 'Food and snacks',
    price: 20.00,
    unitDescription: 'Classic grilled hotdog',
    availableCanteens: ['Main Canteen', 'College Canteen', 'Elementary Canteen'],
  );

  setUp(() {
    CartService.instance.clearCart();
  });

  test('Cart starts empty', () {
    expect(CartService.instance.isEmpty, isTrue);
    expect(CartService.instance.totalItemCount, 0);
    expect(CartService.instance.subtotal, 0.0);
    expect(CartService.instance.items, isEmpty);
  });

  test('Adding items updates quantities, line totals, and subtotal', () {
    CartService.instance.addItem(siomai, quantity: 2); // 2 * 30 = 60
    CartService.instance.addItem(mountainDew, quantity: 1); // 1 * 25 = 25
    CartService.instance.addItem(banana, quantity: 1); // 1 * 15 = 15

    expect(CartService.instance.items.length, 3);
    expect(CartService.instance.totalItemCount, 4);
    expect(CartService.instance.subtotal, 100.00); // 60 + 25 + 15 = 100

    expect(CartService.instance.getQuantity('food-siomai'), 2);
    expect(CartService.instance.getQuantity('bev-dew'), 1);
    expect(CartService.instance.getQuantity('des-banana'), 1);
  });

  test('Adding item with customized selected canteen', () {
    final collegeHotdog = hotdog.copyWith(canteen: 'College Canteen');
    CartService.instance.addItem(collegeHotdog, quantity: 2); // 2 * 20 = 40

    expect(CartService.instance.items.length, 1);
    expect(CartService.instance.items.first.item.canteen, 'College Canteen');
    expect(CartService.instance.subtotal, 40.00);
    expect(CartService.instance.generateOrderDescription(), '2x Hotdog');
  });

  test('Adding existing item increments quantity in place', () {
    CartService.instance.addItem(siomai, quantity: 1);
    CartService.instance.addItem(siomai, quantity: 2);

    expect(CartService.instance.items.length, 1);
    expect(CartService.instance.getQuantity('food-siomai'), 3);
    expect(CartService.instance.subtotal, 90.00);
  });

  test('Increment, decrement, and remove item from cart', () {
    CartService.instance.addItem(siomai, quantity: 2);
    CartService.instance.incrementQuantity('food-siomai');
    expect(CartService.instance.getQuantity('food-siomai'), 3);

    CartService.instance.decrementQuantity('food-siomai');
    expect(CartService.instance.getQuantity('food-siomai'), 2);

    CartService.instance.removeItem('food-siomai');
    expect(CartService.instance.isEmpty, isTrue);
  });

  test('Generates order description and serialized items for runner', () {
    CartService.instance.addItem(siomai, quantity: 2);
    CartService.instance.addItem(mountainDew, quantity: 1);

    final summary = CartService.instance.generateOrderDescription();
    expect(summary, '2x Pork Siomai with rice, 1x Mountain dew (Plastic bottle)');

    final serialized = CartService.instance.serializeItems();
    expect(serialized.length, 2);
    expect(serialized.first['quantity'], 2);
    expect(serialized.first['line_total'], 60.0);
  });
}
