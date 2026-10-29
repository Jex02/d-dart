import 'package:flutter/material.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _selectedIndex = 0;

  // D-Dart Theme Colors
  static const Color primaryMaroon = Color(0xFF7A0000);
  static const Color accentGold = Color(0xFFE5A824);
  static const Color searchFieldBg = Color(0xFFF4EDED);
  static const Color outlineBorderColor = Color(0xFFB0B0B0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryMaroon,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar: Logo, Notification, Profile Avatar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'D',
                          style: TextStyle(color: accentGold),
                        ),
                        TextSpan(
                          text: '-DART',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 4),
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage('https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150'),
                    ),
                  ),
                ],
              ),
            ),

            // Main White Body Content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting Header
                      const Text(
                        'Good day!',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                          color: Color(0xFF1E1E1E),
                          height: 1.1,
                        ),
                      ),
                      const Text(
                        'Jorge!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'What would you like today?',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'serif',
                          fontStyle: FontStyle.italic,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search Box
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: searchFieldBg,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const TextField(
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search for food, drinks or stores',
                            hintStyle: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black45,
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Category Icons: Food & Snacks, Drinks, Campus Stores
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCategoryItem(
                            iconWidget: const Icon(Icons.lunch_dining, size: 36, color: Color(0xFFB56565)),
                            label: 'Food\n& Snacks',
                          ),
                          _buildCategoryItem(
                            iconWidget: const Icon(Icons.local_drink, size: 36, color: Color(0xFF2C3E50)),
                            label: 'Drinks\n',
                          ),
                          _buildCategoryItem(
                            iconWidget: const Icon(Icons.storefront_outlined, size: 36, color: Color(0xFF2C3E50)),
                            label: 'Campus\nStores',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Choose Canteen Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Choose Canteen',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                          InkWell(
                            onTap: () {},
                            child: const Row(
                              children: [
                                Text(
                                  'View All',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: primaryMaroon,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward, size: 14, color: primaryMaroon),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Canteen Cards
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCanteenCard(
                            label: 'Main Canteen',
                            child: Image.asset(
                              'assets/lrac.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.restaurant, color: Colors.grey),
                              ),
                            ),
                          ),
                          _buildCanteenCard(
                            label: 'College Canteen',
                            child: Container(color: Colors.white),
                          ),
                          _buildCanteenCard(
                            label: 'Elementary\nCanteen',
                            child: Container(color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Quick Actions Header
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Quick Actions Buttons + Runner Update Card
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Buttons
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildQuickActionButton('View Campus\nFavorites'),
                                const SizedBox(height: 10),
                                _buildQuickActionButton('Customize\nOrder'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Right Runner Update Card
                          Expanded(
                            flex: 6,
                            child: Container(
                              height: 126,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: outlineBorderColor, width: 0.8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'R u n n e r   U p d a t e',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.local_shipping_outlined,
                                    size: 44,
                                    color: Colors.black87,
                                  ),
                                  Text(
                                    'Runner is still ordering...',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),

                      // Order.Run.Deliver. Tagline
                      Center(
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 16,
                              letterSpacing: 2.0,
                            ),
                            children: [
                              TextSpan(
                                text: 'Order. ',
                                style: TextStyle(color: Color(0xFF1E1E1E)),
                              ),
                              TextSpan(
                                text: 'Run. ',
                                style: TextStyle(color: accentGold),
                              ),
                              TextSpan(
                                text: 'Deliver.',
                                style: TextStyle(color: primaryMaroon),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: primaryMaroon,
          unselectedItemColor: primaryMaroon,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              label: 'Cart',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem({required Widget iconWidget, required String label}) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: outlineBorderColor, width: 0.9),
          ),
          alignment: Alignment.center,
          child: iconWidget,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: primaryMaroon,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  Widget _buildCanteenCard({required String label, required Widget child}) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: outlineBorderColor, width: 0.9),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: child,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: primaryMaroon,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(String label) {
    return Container(
      width: double.infinity,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryMaroon.withOpacity(0.55), width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: primaryMaroon,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward, size: 14, color: Colors.black87),
        ],
      ),
    );
  }
}