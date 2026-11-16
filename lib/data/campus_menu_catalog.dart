import '../models/cart_item.dart';

class CampusMenuCatalog {
  static const List<String> categories = [
    'Food and snacks',
    'Beverages',
    'Desserts',
  ];

  static final List<CanteenMenuItem> allItems = [
    // -------------------------------------------------------------------------
    // FOOD AND SNACKS
    // -------------------------------------------------------------------------
    const CanteenMenuItem(
      id: 'food-hotdog',
      name: 'Hotdog',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 20.00,
      unitDescription: 'Classic grilled hotdog with ketchup/mayo',
      imageUrl: 'https://images.unsplash.com/photo-1619740455993-9e612b1af08a?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'College Canteen', 'Elementary Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-siomai',
      name: 'Pork Siomai with rice',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 30.00,
      unitDescription: '3 for 30 Pesos with chili garlic & calamansi',
      imageUrl: 'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'College Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-burger',
      name: 'Burger',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 35.00,
      unitDescription: 'Classic burger with dressing',
      imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'College Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-egg-rice',
      name: 'Egg w/ rice',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 25.00,
      unitDescription: 'Sunny side up with garlic rice',
      imageUrl: 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Elementary Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-pancit',
      name: 'Pancit Canton',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 25.00,
      unitDescription: 'With boiled egg & calamansi',
      imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'College Canteen', 'Elementary Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-tocilog',
      name: 'Tocilog',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 55.00,
      unitDescription: 'Sweet pork tocino, egg & sinangag',
      imageUrl: 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'College Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-footlong',
      name: 'Footlong',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 40.00,
      unitDescription: 'Footlong hotdog sandwich with cheese',
      imageUrl: 'https://images.unsplash.com/photo-1627059173079-58ec789fc57d?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'College Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-nuggets',
      name: 'Chicken Nuggets w/ Rice',
      canteen: 'Elementary Canteen',
      category: 'Food and snacks',
      price: 45.00,
      unitDescription: '4 pcs nuggets with BBQ sauce & rice',
      imageUrl: 'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Elementary Canteen', 'Main Canteen'],
    ),

    // -------------------------------------------------------------------------
    // BEVERAGES / DRINKS
    // -------------------------------------------------------------------------
    const CanteenMenuItem(
      id: 'bev-dew',
      name: 'Mountain dew (Plastic bottle)',
      canteen: 'Main Canteen',
      category: 'Beverages',
      price: 25.00,
      unitDescription: '25 Pesos/bottle',
      imageUrl: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'College Canteen', 'Elementary Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-c2',
      name: 'C2 Green Tea Apple',
      canteen: 'Main Canteen',
      category: 'Beverages',
      price: 20.00,
      unitDescription: '500ml chilled bottle',
      imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'College Canteen', 'Elementary Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-water',
      name: 'Mineral Water',
      canteen: 'Main Canteen',
      category: 'Beverages',
      price: 15.00,
      unitDescription: '500ml purified cold bottle',
      imageUrl: 'https://images.unsplash.com/photo-1559839914-1b39868735df?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'College Canteen', 'Elementary Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-calamansi',
      name: 'Fresh Calamansi Juice',
      canteen: 'Main Canteen',
      category: 'Beverages',
      price: 20.00,
      unitDescription: '16oz freshly squeezed cold cup',
      imageUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'College Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-coffee',
      name: 'Iced Coffee Latte',
      canteen: 'College Canteen',
      category: 'Beverages',
      price: 35.00,
      unitDescription: '16oz brewed coffee with fresh milk',
      imageUrl: 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['College Canteen', 'Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-juice',
      name: 'Orange Juice Box',
      canteen: 'Elementary Canteen',
      category: 'Beverages',
      price: 18.00,
      unitDescription: '250ml tetra pack',
      imageUrl: 'https://images.unsplash.com/photo-1613478223719-2ab802602423?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Elementary Canteen', 'Main Canteen'],
    ),

    // -------------------------------------------------------------------------
    // DESSERTS
    // -------------------------------------------------------------------------
    const CanteenMenuItem(
      id: 'des-banana',
      name: 'Banana',
      canteen: 'Main Canteen',
      category: 'Desserts',
      price: 15.00,
      unitDescription: '15 pesos/fruit',
      imageUrl: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'College Canteen', 'Elementary Canteen'],
    ),
    const CanteenMenuItem(
      id: 'des-turon',
      name: 'Turon (2 pcs)',
      canteen: 'Main Canteen',
      category: 'Desserts',
      price: 20.00,
      unitDescription: 'Crispy caramelized banana roll',
      imageUrl: 'https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'College Canteen'],
    ),
    const CanteenMenuItem(
      id: 'des-halohalo',
      name: 'Special Halo-Halo',
      canteen: 'Main Canteen',
      category: 'Desserts',
      price: 45.00,
      unitDescription: 'Shaved ice, milk, ube & leche flan',
      imageUrl: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'College Canteen'],
    ),
    const CanteenMenuItem(
      id: 'des-waffle',
      name: 'Belgian Chocolate Waffle',
      canteen: 'College Canteen',
      category: 'Desserts',
      price: 30.00,
      unitDescription: 'Crispy waffle with chocolate dip',
      imageUrl: 'https://images.unsplash.com/photo-1562376552-0d160a2f238d?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['College Canteen', 'Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'des-cookies',
      name: 'Chocolate Chip Cookies (3 pcs)',
      canteen: 'Elementary Canteen',
      category: 'Desserts',
      price: 20.00,
      unitDescription: 'Freshly baked cookies',
      imageUrl: 'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Elementary Canteen', 'Main Canteen'],
    ),
  ];

  static List<CanteenMenuItem> getItemsByCategory(String categoryName) {
    final catLower = categoryName.toLowerCase();
    return allItems.where((item) {
      final itemCat = item.category.toLowerCase();
      if (catLower.contains('food') || catLower.contains('snack')) {
        return itemCat.contains('food');
      }
      if (catLower.contains('drink') || catLower.contains('bev')) {
        return itemCat.contains('beverage');
      }
      if (catLower.contains('dessert')) {
        return itemCat.contains('dessert');
      }
      return itemCat == catLower;
    }).toList();
  }

  static List<CanteenMenuItem> getItemsByCanteen(String canteenName) {
    return allItems.where((item) {
      return item.canteensList
          .any((c) => c.toLowerCase() == canteenName.toLowerCase());
    }).toList();
  }

  static List<CanteenMenuItem> getItemsByCanteenAndCategory(
    String canteenName,
    String categoryName,
  ) {
    final byCat = getItemsByCategory(categoryName);
    return byCat.where((item) {
      return item.canteensList
          .any((c) => c.toLowerCase() == canteenName.toLowerCase());
    }).toList();
  }
}
