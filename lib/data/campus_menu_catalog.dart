import '../models/cart_item.dart';

class CampusMenuCatalog {
  static const List<String> categories = [
    'Food and snacks',
    'Beverages',
    'Desserts',
  ];

  static final List<CanteenMenuItem> allItems = [
    // -------------------------------------------------------------------------
    // 1. FOOD AND SNACKS (Main Canteen, Mini Canteen, Elementary, Kiosks)
    // -------------------------------------------------------------------------
    const CanteenMenuItem(
      id: 'food-siomai',
      name: 'Pork Siomai with rice',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 30.00,
      unitDescription: '3 for 30 Pesos with chili garlic & calamansi',
      imageUrl: 'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-burger',
      name: 'Burger',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 35.00,
      unitDescription: 'Classic beef burger with dressing',
      imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-cheeseburger',
      name: 'Cheesy Bacon Burger',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 45.00,
      unitDescription: 'Burger with cheddar cheese slice & crispy bacon',
      imageUrl: 'https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-egg-rice',
      name: 'Egg w/ rice',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 25.00,
      unitDescription: 'Sunny side up with garlic fried rice',
      imageUrl: 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Highschool Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-pancit',
      name: 'Pancit Canton',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 25.00,
      unitDescription: 'With boiled egg & calamansi',
      imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen', 'Highschool Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-tocilog',
      name: 'Tocilog',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 55.00,
      unitDescription: 'Sweet pork tocino, egg & sinangag',
      imageUrl: 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-tapsilog',
      name: 'Tapsilog Special',
      canteen: 'Mini Canteen',
      category: 'Food and snacks',
      price: 65.00,
      unitDescription: 'Tender beef tapa with fried egg & garlic rice',
      imageUrl: 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Mini Canteen', 'Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-bangsilog',
      name: 'Bangsilog',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 60.00,
      unitDescription: 'Pan-fried daing na bangus with egg & rice',
      imageUrl: 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-sisig',
      name: 'Pork Sisig w/ Rice',
      canteen: 'Mini Canteen',
      category: 'Food and snacks',
      price: 60.00,
      unitDescription: 'Sizzling savory pork sisig with egg & calamansi',
      imageUrl: 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Mini Canteen', 'Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-hotdog',
      name: 'Hotdog',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 20.00,
      unitDescription: 'Classic grilled red hotdog with dressing',
      imageUrl: 'https://images.unsplash.com/photo-1619740455993-9e612b1af08a?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen', 'Highschool Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-footlong',
      name: 'Footlong',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 40.00,
      unitDescription: 'Footlong hotdog sandwich with cheese & ketchup',
      imageUrl: 'https://images.unsplash.com/photo-1627059173079-58ec789fc57d?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-corndog',
      name: 'Mozzarella Corndog',
      canteen: 'Mini Canteen',
      category: 'Food and snacks',
      price: 45.00,
      unitDescription: 'Half mozzarella half sausage with honey mustard',
      imageUrl: 'https://images.unsplash.com/photo-1627059173079-58ec789fc57d?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Mini Canteen', 'Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-nuggets',
      name: 'Chicken Nuggets w/ Rice',
      canteen: 'Highschool Canteen',
      category: 'Food and snacks',
      price: 45.00,
      unitDescription: '4 pcs crispy nuggets with BBQ sauce & rice',
      imageUrl: 'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Highschool Canteen', 'Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-fries',
      name: 'Cheese French Fries',
      canteen: 'Mini Canteen',
      category: 'Food and snacks',
      price: 30.00,
      unitDescription: 'Crispy crinkle-cut fries coated in cheese powder',
      imageUrl: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Mini Canteen', 'Highschool Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-lumpia',
      name: 'Shanghai Rolls w/ Rice',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 35.00,
      unitDescription: '4 pcs crispy pork lumpia with sweet chili sauce',
      imageUrl: 'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-shawarma',
      name: 'Beef Shawarma Rice',
      canteen: 'Main Canteen',
      category: 'Food and snacks',
      price: 55.00,
      unitDescription: 'Spiced beef shawarma with garlic cucumber sauce',
      imageUrl: 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-kwek',
      name: 'Kwek-Kwek & Fishballs',
      canteen: 'Mini Canteen',
      category: 'Food and snacks',
      price: 20.00,
      unitDescription: '4 pcs quail eggs & 5 fishballs with sweet brown sauce',
      imageUrl: 'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Mini Canteen', 'Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'food-porkchop',
      name: 'Breaded Porkchop w/ Rice',
      canteen: 'Mini Canteen',
      category: 'Food and snacks',
      price: 60.00,
      unitDescription: 'Golden deep-fried porkchop with mushroom gravy',
      imageUrl: 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Mini Canteen', 'Main Canteen'],
    ),

    // -------------------------------------------------------------------------
    // 2. BEVERAGES / DRINKS
    // -------------------------------------------------------------------------
    const CanteenMenuItem(
      id: 'bev-dew',
      name: 'Mountain dew (Plastic bottle)',
      canteen: 'Main Canteen',
      category: 'Beverages',
      price: 25.00,
      unitDescription: '25 Pesos/bottle 500ml',
      imageUrl: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen', 'Highschool Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-coke',
      name: 'Coca-Cola Mismo',
      canteen: 'Main Canteen',
      category: 'Beverages',
      price: 20.00,
      unitDescription: '300ml chilled bottle',
      imageUrl: 'https://images.unsplash.com/photo-1554866585-cd94860890b7?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen', 'Highschool Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-sprite',
      name: 'Sprite Mismo',
      canteen: 'Main Canteen',
      category: 'Beverages',
      price: 20.00,
      unitDescription: '300ml chilled lemon-lime soda',
      imageUrl: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-royal',
      name: 'Royal Tru-Orange Mismo',
      canteen: 'Highschool Canteen',
      category: 'Beverages',
      price: 20.00,
      unitDescription: '300ml chilled orange soda',
      imageUrl: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Highschool Canteen', 'Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-c2',
      name: 'C2 Green Tea Apple',
      canteen: 'Main Canteen',
      category: 'Beverages',
      price: 20.00,
      unitDescription: '500ml chilled bottle',
      imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen', 'Highschool Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-c2-lemon',
      name: 'C2 Green Tea Lemon',
      canteen: 'Main Canteen',
      category: 'Beverages',
      price: 20.00,
      unitDescription: '500ml chilled bottle',
      imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-water',
      name: 'Mineral Water 500ml',
      canteen: 'Main Canteen',
      category: 'Beverages',
      price: 15.00,
      unitDescription: '500ml purified cold bottle',
      imageUrl: 'https://images.unsplash.com/photo-1559839914-1b39868735df?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen', 'Highschool Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-water-1l',
      name: 'Nature Spring 1 Liter',
      canteen: 'Main Canteen',
      category: 'Beverages',
      price: 25.00,
      unitDescription: '1 Liter cold purified water',
      imageUrl: 'https://images.unsplash.com/photo-1559839914-1b39868735df?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-calamansi',
      name: 'Fresh Calamansi Juice',
      canteen: 'Main Canteen',
      category: 'Beverages',
      price: 20.00,
      unitDescription: '16oz freshly squeezed cold cup with honey',
      imageUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-iced-tea',
      name: 'House Iced Tea',
      canteen: 'Main Canteen',
      category: 'Beverages',
      price: 15.00,
      unitDescription: '16oz sweet refreshing iced tea with ice',
      imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen', 'Highschool Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-coffee',
      name: 'Iced Coffee Latte',
      canteen: 'Mini Canteen',
      category: 'Beverages',
      price: 35.00,
      unitDescription: '16oz cold brewed coffee with milk & syrup',
      imageUrl: 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Mini Canteen', 'Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-milo',
      name: 'Iced Milo Dinosaur',
      canteen: 'Mini Canteen',
      category: 'Beverages',
      price: 30.00,
      unitDescription: 'Cold chocolate milk with extra Milo powder',
      imageUrl: 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Mini Canteen', 'Highschool Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-gulaman',
      name: 'Sago\'t Gulaman Cooler',
      canteen: 'Mini Canteen',
      category: 'Beverages',
      price: 15.00,
      unitDescription: 'Sweet brown sugar cooler with sago pearls & jelly',
      imageUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Mini Canteen', 'Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-juice',
      name: 'Orange Juice Box',
      canteen: 'Highschool Canteen',
      category: 'Beverages',
      price: 18.00,
      unitDescription: '250ml tetra pack with straw',
      imageUrl: 'https://images.unsplash.com/photo-1613478223719-2ab802602423?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Highschool Canteen', 'Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'bev-chuckie',
      name: 'Nestle Chuckie Box',
      canteen: 'Highschool Canteen',
      category: 'Beverages',
      price: 25.00,
      unitDescription: '250ml chilled chocolate box',
      imageUrl: 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Highschool Canteen', 'Mini Canteen'],
    ),

    // -------------------------------------------------------------------------
    // 3. DESSERTS & SWEETS
    // -------------------------------------------------------------------------
    const CanteenMenuItem(
      id: 'des-banana',
      name: 'Banana',
      canteen: 'Main Canteen',
      category: 'Desserts',
      price: 15.00,
      unitDescription: '15 pesos/fruit fresh sweet banana',
      imageUrl: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen', 'Highschool Canteen'],
    ),
    const CanteenMenuItem(
      id: 'des-turon',
      name: 'Turon (2 pcs)',
      canteen: 'Main Canteen',
      category: 'Desserts',
      price: 20.00,
      unitDescription: 'Crispy caramelized banana roll with jackfruit',
      imageUrl: 'https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'des-halohalo',
      name: 'Special Halo-Halo',
      canteen: 'Main Canteen',
      category: 'Desserts',
      price: 45.00,
      unitDescription: 'Shaved ice with ube, leche flan & milk',
      imageUrl: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'des-waffle',
      name: 'Belgian Chocolate Waffle',
      canteen: 'Mini Canteen',
      category: 'Desserts',
      price: 30.00,
      unitDescription: 'Crispy waffle with chocolate dip',
      imageUrl: 'https://images.unsplash.com/photo-1562376552-0d160a2f238d?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Mini Canteen', 'Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'des-waffle-cheese',
      name: 'Belgian Cheese Waffle',
      canteen: 'Mini Canteen',
      category: 'Desserts',
      price: 30.00,
      unitDescription: 'Crispy waffle with melted cheese',
      imageUrl: 'https://images.unsplash.com/photo-1562376552-0d160a2f238d?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Mini Canteen', 'Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'des-cookies',
      name: 'Chocolate Chip Cookies (3 pcs)',
      canteen: 'Highschool Canteen',
      category: 'Desserts',
      price: 20.00,
      unitDescription: 'Freshly baked chocolate cookies',
      imageUrl: 'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Highschool Canteen', 'Main Canteen'],
    ),
    const CanteenMenuItem(
      id: 'des-mango-float',
      name: 'Mango Float Cup',
      canteen: 'Main Canteen',
      category: 'Desserts',
      price: 40.00,
      unitDescription: 'Layered graham crackers, cream & fresh mango',
      imageUrl: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'des-lecheflan',
      name: 'Leche Flan Slice',
      canteen: 'Main Canteen',
      category: 'Desserts',
      price: 30.00,
      unitDescription: 'Caramel custard flan slice',
      imageUrl: 'https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen'],
    ),
    const CanteenMenuItem(
      id: 'des-cornetto',
      name: 'Cornetto Ice Cream Cone',
      canteen: 'Main Canteen',
      category: 'Desserts',
      price: 35.00,
      unitDescription: 'Drumstick cone with chocolate tip',
      imageUrl: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Main Canteen', 'Mini Canteen', 'Highschool Canteen'],
    ),
    const CanteenMenuItem(
      id: 'des-donut',
      name: 'Choco Glazed Donut',
      canteen: 'Mini Canteen',
      category: 'Desserts',
      price: 25.00,
      unitDescription: 'Soft ring donut with thick chocolate glaze',
      imageUrl: 'https://images.unsplash.com/photo-1527515862127-a4fc05baf7a5?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Mini Canteen', 'Highschool Canteen'],
    ),
    const CanteenMenuItem(
      id: 'des-pichi',
      name: 'Pichi-Pichi with Cheese',
      canteen: 'Mini Canteen',
      category: 'Desserts',
      price: 25.00,
      unitDescription: '4 pcs chewy cassava cake with cheese',
      imageUrl: 'https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=400&q=80',
      availableCanteens: ['Mini Canteen', 'Main Canteen'],
    ),
  ];

  static bool matchesCategory(String itemCategory, String filterCategory) {
    final catLower = filterCategory.trim().toLowerCase();
    final itemCat = itemCategory.trim().toLowerCase();
    if (catLower.isEmpty ||
        catLower == 'all' ||
        catLower.contains('campus canteen menu') ||
        catLower.contains('all menu')) {
      return true;
    }
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
  }

  static List<CanteenMenuItem> getItemsByCategory(String categoryName) {
    return allItems
        .where((item) => matchesCategory(item.category, categoryName))
        .toList();
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
