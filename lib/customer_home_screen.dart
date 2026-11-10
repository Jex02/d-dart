import 'package:flutter/material.dart';
import 'cor_upload_screen.dart';
import 'login.dart';
import 'main_dashboard.dart';
import 'models/delivery_order.dart';
import 'models/user_profile.dart';
import 'order_tracking_screen.dart';
import 'pabili_request_screen.dart';
import 'services/duty_lock_service.dart';
import 'services/supabase_service.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _selectedIndex = 0;
  UserProfile? _profile;
  final _searchController = TextEditingController();

  static const Color primaryMaroon = Color(0xFF7A0000);
  static const Color accentGold = Color(0xFFE5A824);
  static const Color searchFieldBg = Color(0xFFF4EDED);
  static const Color outlineBorderColor = Color(0xFFB0B0B0);

  @override
  void initState() {
    super.initState();
    _loadProfileAndExpireStale();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileAndExpireStale() async {
    await SupabaseService().expireStaleOrders();
    final profile = await SupabaseService().fetchUserProfileModel();
    if (mounted) {
      setState(() => _profile = profile);
    }
  }

  void _openPabili({String? pickup, String? hint}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PabiliRequestScreen(
          initialPickup: pickup,
          initialHint: hint,
        ),
      ),
    ).then((_) => _loadProfileAndExpireStale());
  }

  void _openOrderTracking(String orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(orderId: orderId, isRunner: false),
      ),
    ).then((_) => _loadProfileAndExpireStale());
  }

  void _switchMode() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainDashboard()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (_profile?.fullName.trim().isNotEmpty ?? false)
        ? _profile!.fullName.trim().split(' ').first
        : 'Wildcat';

    return Scaffold(
      floatingActionButton: _selectedIndex == 2
          ? null
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFF7F0000),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('New Pabili'),
              onPressed: () => _openPabili(),
            ),
      backgroundColor: primaryMaroon,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Switch Mode',
                    icon: const Icon(Icons.swap_horiz, color: Colors.white),
                    onPressed: _switchMode,
                  ),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                      children: [
                        TextSpan(text: 'D', style: TextStyle(color: accentGold)),
                        TextSpan(text: '-DART', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Active Orders',
                    icon: const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                    onPressed: () => setState(() => _selectedIndex = 1),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _selectedIndex = 2),
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: accentGold.withOpacity(0.25),
                        child: Text(
                          firstName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: primaryMaroon,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Body Content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        _buildHomeTab(firstName),
                        _buildOrdersTab(),
                        _buildProfileTab(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
          unselectedItemColor: Colors.grey.shade600,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(String firstName) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Good day,',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
              color: Color(0xFF1E1E1E),
              height: 1.1,
            ),
          ),
          Text(
            '$firstName!',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
              color: primaryMaroon,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'What would you like delivered on campus today?',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'serif',
              fontStyle: FontStyle.italic,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),

          // Search Box -> opens Pabili request prefilled with query
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: searchFieldBg,
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (query) {
                final trimmed = query.trim();
                _searchController.clear();
                _openPabili(hint: trimmed);
              },
              decoration: const InputDecoration(
                border: InputBorder.none,
                icon: Icon(Icons.search, size: 18, color: Colors.black54),
                hintText: 'Request food, drinks, or school supplies...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Categories
          Row(
            children: [
              Expanded(
                child: _buildCategoryItem(
                  iconWidget: const Icon(Icons.lunch_dining, size: 32, color: Color(0xFFB56565)),
                  label: 'Food\n& Snacks',
                  onTap: () => _openPabili(pickup: 'Main Canteen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCategoryItem(
                  iconWidget: const Icon(Icons.local_drink, size: 32, color: Color(0xFF2C3E50)),
                  label: 'Drinks\n',
                  onTap: () => _openPabili(pickup: 'College Canteen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCategoryItem(
                  iconWidget: const Icon(Icons.storefront_outlined, size: 32, color: Color(0xFF2C3E50)),
                  label: 'Campus\nStores',
                  onTap: () => _openPabili(pickup: 'Campus Kiosks'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Choose Pickup Canteen',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              InkWell(
                onTap: () => _openPabili(),
                child: const Row(
                  children: [
                    Text(
                      'Custom Form',
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
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildCanteenCard(
                  label: 'Main Canteen',
                  onTap: () => _openPabili(pickup: 'Main Canteen'),
                  child: Image.asset(
                    'assets/lrac.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.restaurant, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCanteenCard(
                  label: 'College Canteen',
                  onTap: () => _openPabili(pickup: 'College Canteen'),
                  child: Container(
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.local_cafe_outlined, color: primaryMaroon),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCanteenCard(
                  label: 'Elementary\nCanteen',
                  onTap: () => _openPabili(pickup: 'Elementary Canteen'),
                  child: Container(
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.fastfood_outlined, color: primaryMaroon),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          const Text(
            'Quick Actions & Live Tracking',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _selectedIndex = 1),
                      child: _buildQuickActionButton('Track My\nOrders'),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _openPabili(),
                      child: _buildQuickActionButton('Customize\nPabili Order'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 6,
                child: _buildLiveRunnerUpdateCard(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveRunnerUpdateCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService().streamCustomerOrders(),
      builder: (context, snapshot) {
        final orders = (snapshot.data ?? [])
            .map(DeliveryOrder.fromJson)
            .where((o) =>
                o.effectiveStatus() != 'completed' &&
                o.effectiveStatus() != 'cancelled' &&
                o.effectiveStatus() != 'expired')
            .toList();

        final activeOrder = orders.isNotEmpty ? orders.first : null;

        return InkWell(
          onTap: activeOrder != null
              ? () => _openOrderTracking(activeOrder.id)
              : () => _openPabili(),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 126,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: activeOrder != null ? primaryMaroon : outlineBorderColor,
                width: activeOrder != null ? 1.4 : 0.8,
              ),
            ),
            child: activeOrder == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'RUNNER UPDATE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Icon(Icons.local_shipping_outlined, size: 38, color: Colors.black54),
                      Text(
                        'No active orders.\nTap to create one!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LIVE: ${activeOrder.effectiveStatus().toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: primaryMaroon,
                        ),
                      ),
                      Text(
                        'OTP: ${activeOrder.verificationCode}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: primaryMaroon,
                        ),
                      ),
                      Text(
                        activeOrder.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10.5, color: Colors.black87),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService().streamCustomerOrders(),
      builder: (context, snapshot) {
        final orders = (snapshot.data ?? []).map(DeliveryOrder.fromJson).toList();
        if (orders.isEmpty) {
          return const Center(
            child: Text(
              'You have not placed any Pabili requests yet.\nTap "New Pabili" to start!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadProfileAndExpireStale,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final status = order.effectiveStatus();
              final isActive = status != 'completed' &&
                  status != 'cancelled' &&
                  status != 'expired';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openOrderTracking(order.id),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? primaryMaroon.withOpacity(0.12)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? primaryMaroon : Colors.black54,
                                ),
                              ),
                            ),
                            Text(
                              'Total ₱${order.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryMaroon,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          order.description,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.pickupLocation} → ${order.dropoffLocation}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        if (isActive) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'OTP Code: ${order.verificationCode}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryMaroon,
                                  fontSize: 12,
                                ),
                              ),
                              const Text(
                                'Tap to Track / Manage →',
                                style: TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProfileTab() {
    final profile = _profile;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Account Profile',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryMaroon),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.fullName.isNotEmpty == true
                      ? profile!.fullName
                      : 'Signed-in User',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.email ?? SupabaseService().currentUser?.email ?? '',
                  style: const TextStyle(color: Colors.black54),
                ),
                const Divider(height: 20),
                Text('Account Type: ${profile?.accountTypeLabel ?? 'Student'}'),
                const SizedBox(height: 4),
                Text('ID Number: ${profile?.studentId ?? '-'}'),
                const SizedBox(height: 4),
                Text('Verification Status: ${profile?.verificationLabel ?? 'Pending'}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ListTile(
          leading: const Icon(Icons.swap_horiz, color: primaryMaroon),
          title: const Text('Switch Mode (Customer / Runner)'),
          onTap: _switchMode,
        ),
        if (profile == null || profile.isStudent)
          ListTile(
            leading: const Icon(Icons.school_outlined, color: primaryMaroon),
            title: const Text('Manage COR / Study Load'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CorUploadScreen()),
              );
            },
          ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          onTap: () async {
            await SupabaseService().signOut();
            DutyLockService.reset();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildCategoryItem({
    required Widget iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: double.infinity,
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
      ),
    );
  }

  Widget _buildCanteenCard({
    required String label,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: double.infinity,
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
      ),
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
                fontSize: 10.5,
                color: primaryMaroon,
                fontWeight: FontWeight.w600,
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
