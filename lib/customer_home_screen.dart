import 'package:flutter/material.dart';
import 'canteen_category_screen.dart';
import 'canteen_menu_screen.dart';
import 'cart_screen.dart';
import 'category_browse_screen.dart';
import 'cor_upload_screen.dart';
import 'login.dart';
import 'main_dashboard.dart';
import 'models/class_schedule.dart';
import 'models/delivery_order.dart';
import 'models/problem_report.dart';
import 'models/user_profile.dart';
import 'order_tracking_screen.dart';
import 'pabili_request_screen.dart';
import 'services/cart_service.dart';
import 'services/duty_lock_service.dart';
import 'services/supabase_service.dart';
import 'widgets/cor_timetable_dialog.dart';
import 'widgets/responsive_shell.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _selectedIndex = 0;
  UserProfile? _profile;
  String? _idPhotoUrl;
  final _searchController = TextEditingController();

  static const Color primaryMaroon = DDartTheme.deepMaroon;
  static const Color accentGold = DDartTheme.brightGold;
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
    await DutyLockService.syncFromSupabase();
    final profile = await SupabaseService().fetchUserProfileModel();
    String? idUrl;
    if (profile?.idDocumentPath != null && profile!.idDocumentPath!.isNotEmpty) {
      idUrl = await SupabaseService().getSignedDocumentUrl(profile.idDocumentPath!);
    }
    if (mounted) {
      setState(() {
        _profile = profile;
        _idPhotoUrl = idUrl;
      });
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

  void _openCanteenCategory(String canteenName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CanteenCategoryScreen(
          canteenName: canteenName,
          userName: _profile?.firstName,
        ),
      ),
    ).then((_) => _loadProfileAndExpireStale());
  }

  void _openCategoryBrowse(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryBrowseScreen(
          categoryTitle: category,
        ),
      ),
    ).then((_) => _loadProfileAndExpireStale());
  }

  void _openSearchResults(String query) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryBrowseScreen(
          categoryTitle: 'Search: $query',
          initialQuery: query,
        ),
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

  Future<void> _openGeneralReportDialog() async {
    String category = 'app_issue';
    final descCtrl = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Report a Problem'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: ProblemReport.categoryLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => category = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Describe the issue',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    final text = descCtrl.text.trim();
    descCtrl.dispose();
    if (submit == true && text.isNotEmpty) {
      await SupabaseService().submitProblemReport(
        category: category,
        description: text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Problem report submitted to Administrators.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _profile?.firstName ?? 'Wildcat';
    final canSwitchToRunner = _profile == null || _profile!.isStudent;

    return ResponsiveMobileShell(
      mobileBackground: primaryMaroon,
      child: Scaffold(
        backgroundColor: primaryMaroon,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                child: Row(
                  children: [
                    if (canSwitchToRunner)
                      IconButton(
                        tooltip: 'Switch Mode',
                        icon: const Icon(Icons.swap_horiz, color: Colors.white),
                        onPressed: _switchMode,
                      )
                    else
                      const SizedBox(width: 8),
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
                    if (_profile != null && _profile!.isFacultyOrStaff) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentGold.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'FACULTY',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      tooltip: 'Active Orders',
                      icon: const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                      onPressed: () => setState(() => _selectedIndex = 2),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedIndex = 3),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: ClipOval(
                          child: _idPhotoUrl != null
                              ? Image.network(
                                  _idPhotoUrl!,
                                  fit: BoxFit.cover,
                                  alignment: const Alignment(-0.55, -0.35),
                                  errorBuilder: (_, _, _) => _buildSmallAvatarFallback(firstName),
                                )
                              : _buildSmallAvatarFallback(firstName),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        _buildHomeTab(firstName),
                        CartScreen(
                          isEmbeddedTab: true,
                          onSwitchToHome: () => setState(() => _selectedIndex = 0),
                        ),
                        _buildOrdersTab(),
                        _buildProfileTab(canSwitchToRunner),
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
        child: ListenableBuilder(
          listenable: CartService.instance,
          builder: (context, _) {
            final cartCount = CartService.instance.totalItemCount;

            return BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                ScaffoldMessenger.of(context).clearSnackBars();
                setState(() => _selectedIndex = index);
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: primaryMaroon,
              unselectedItemColor: Colors.grey.shade600,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              elevation: 0,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: cartCount > 0
                      ? Badge(
                          label: Text('$cartCount'),
                          child: const Icon(Icons.shopping_cart_outlined),
                        )
                      : const Icon(Icons.shopping_cart_outlined),
                  activeIcon: cartCount > 0
                      ? Badge(
                          label: Text('$cartCount'),
                          child: const Icon(Icons.shopping_cart),
                        )
                      : const Icon(Icons.shopping_cart),
                  label: 'Cart',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  activeIcon: Icon(Icons.receipt_long),
                  label: 'Orders',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  }

  Widget _buildSmallAvatarFallback(String firstName) {
    return CircleAvatar(
      radius: 15,
      backgroundColor: accentGold.withValues(alpha: 0.25),
      child: Text(
        firstName.isNotEmpty ? firstName.substring(0, 1).toUpperCase() : 'W',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
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
                if (trimmed.isNotEmpty) {
                  _openSearchResults(trimmed);
                }
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

          Row(
            children: [
              Expanded(
                child: _buildCategoryItem(
                  iconWidget: const Icon(Icons.lunch_dining, size: 32, color: Color(0xFFB56565)),
                  label: 'Food\n& Snacks',
                  onTap: () => _openCategoryBrowse('Food and snacks'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCategoryItem(
                  iconWidget: const Icon(Icons.local_drink, size: 32, color: Color(0xFF2C3E50)),
                  label: 'Drinks\n',
                  onTap: () => _openCategoryBrowse('Beverages'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCategoryItem(
                  iconWidget: const Icon(Icons.icecream_outlined, size: 32, color: Color(0xFFB56565)),
                  label: 'Dessert\n',
                  onTap: () => _openCategoryBrowse('Desserts'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Choose Pickup Canteen',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E1E),
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
                  label: 'Mini Canteen',
                  onTap: () => _openCanteenCategory('Mini Canteen'),
                  child: Container(
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.storefront_outlined, color: primaryMaroon),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCanteenCard(
                  label: 'Main Canteen',
                  onTap: () => _openCanteenCategory('Main Canteen'),
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
                  label: 'High School\nCanteen',
                  onTap: () => _openCanteenCategory('High School Canteen'),
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
                      onTap: () => setState(() => _selectedIndex = 2),
                      child: _buildQuickActionButton('Track My\nOrders'),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _openCategoryBrowse('Food & Snacks'),
                      child: _buildQuickActionButton('Browse Campus\nCanteen Menu'),
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
        final activeStatus = activeOrder?.effectiveStatus() ?? '';
        final showOtp = activeStatus == 'arrived';

        return InkWell(
          onTap: activeOrder != null
              ? () => _openOrderTracking(activeOrder.id)
              : () => setState(() => _selectedIndex = 2),
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
                        'LIVE: ${activeStatus.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: primaryMaroon,
                        ),
                      ),
                      if (showOtp)
                        Text(
                          'OTP: ${activeOrder.verificationCode}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                            color: primaryMaroon,
                          ),
                        )
                      else
                        const Text(
                          'Tap to Track Live',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
                                    ? primaryMaroon.withValues(alpha: 0.12)
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
                                status == 'arrived'
                                    ? 'OTP Code: ${order.verificationCode}'
                                    : 'OTP unlocks on arrival',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryMaroon,
                                  fontSize: 11.5,
                                ),
                              ),
                              const Text(
                                'Tap to Track →',
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

  void _showScheduleModal() {
    CorTimetableDialog.show(
      context,
      profile: _profile,
      onScheduleUpdated: _loadProfileAndExpireStale,
    );
  }

  void _showFullIdDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('CIT-U Identification Card'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_idPhotoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _idPhotoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 80),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.badge_outlined, size: 60, color: Colors.grey),
                      SizedBox(height: 10),
                      Text('No ID document photo uploaded yet.'),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileTab(bool canSwitchToRunner) {
    final profile = _profile;
    final fullName = profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Signed-in User';
    final firstName = profile?.firstName ?? 'Wildcat';
    final isStudent = profile == null || profile.isStudent;
    final hasVerifiedCor = DutyLockService.verifiedSchedule.isNotEmpty || (profile?.corVerified ?? false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
      children: [
        // -------------------------------------------------------------
        // 1. HERO PROFILE CARD WITH CENTERED LARGE CIRCULAR AVATAR
        // -------------------------------------------------------------
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Large Circular Avatar (Cropped ID photo or Initials)
              GestureDetector(
                onTap: _showFullIdDialog,
                child: Stack(
                  children: [
                    Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accentGold, width: 3.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _idPhotoUrl != null
                            ? Image.network(
                                _idPhotoUrl!,
                                fit: BoxFit.cover,
                                alignment: const Alignment(-0.55, -0.35),
                                errorBuilder: (_, _, _) => _buildInitialsAvatar(firstName),
                              )
                            : _buildInitialsAvatar(firstName),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryMaroon,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.badge, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Full Name
              Text(
                fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'serif',
                  color: Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 6),

              // Role & Verification Pill Badges
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryMaroon.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryMaroon.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '🎓 ${profile?.accountTypeLabel ?? 'Student'}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: primaryMaroon,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (profile?.isVerified ?? false)
                          ? Colors.green.shade50
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (profile?.isVerified ?? false)
                            ? Colors.green.shade400
                            : Colors.amber.shade400,
                      ),
                    ),
                    child: Text(
                      (profile?.isVerified ?? false) ? '✓ Verified' : '⏳ Pending Approval',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: (profile?.isVerified ?? false)
                            ? Colors.green.shade800
                            : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Student ID & Email Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge_outlined, size: 15, color: Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text(
                    profile?.studentId.isNotEmpty == true ? profile!.studentId : 'CIT-U Student',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 14),
                  Icon(Icons.email_outlined, size: 15, color: Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      profile?.email ?? SupabaseService().currentUser?.email ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // -------------------------------------------------------------
        // 2. ENROLLED CLASS SCHEDULE & DUTY LOCK CARD (FOR STUDENTS)
        // -------------------------------------------------------------
        if (isStudent) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 18, color: primaryMaroon),
                        SizedBox(width: 8),
                        Text(
                          'Enrolled Class Schedule',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasVerifiedCor ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasVerifiedCor ? Colors.green.shade300 : Colors.orange.shade300,
                        ),
                      ),
                      child: Text(
                        hasVerifiedCor
                            ? '${DutyLockService.verifiedSchedule.length} Sessions'
                            : 'No COR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasVerifiedCor ? Colors.green.shade800 : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  hasVerifiedCor
                      ? 'Your class hours are synced to automatically pause runner mode during lectures.'
                      : 'Upload your verified Study Load to activate Runner Mode privileges.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 14),

                // Button to open the Schedule Modal
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _showScheduleModal,
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 17, color: Colors.white),
                    label: const Text(
                      'View Full Enrolled Schedule',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryMaroon,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // -------------------------------------------------------------
        // 3. ACCOUNT ACTIONS & SETTINGS LIST
        // -------------------------------------------------------------
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (canSwitchToRunner) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryMaroon.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.swap_horiz, color: primaryMaroon, size: 20),
                  ),
                  title: const Text('Switch Mode (Customer / Runner)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Accept gigs and deliver for peers on campus', style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black38),
                  onTap: _switchMode,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryMaroon.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school_outlined, color: primaryMaroon, size: 20),
                  ),
                  title: const Text('Manage COR / Study Load', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Re-upload or adjust class schedule', style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black38),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CorUploadScreen()),
                    );
                    await DutyLockService.syncFromSupabase();
                    await _loadProfileAndExpireStale();
                  },
                ),
                const Divider(height: 1, indent: 56),
              ],
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.report_problem_outlined, color: Colors.amber, size: 20),
                ),
                title: const Text('Report a Problem / Support', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Submit delivery disputes or app feedback', style: TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black38),
                onTap: _openGeneralReportDialog,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, color: Colors.red, size: 20),
                ),
                title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red, fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red),
                onTap: () async {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  CartService.instance.clearCart();
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
          ),
        ),
      ],
    );
  }

  Widget _buildInitialsAvatar(String firstName) {
    return Container(
      color: primaryMaroon,
      child: Center(
        child: Text(
          firstName.isNotEmpty ? firstName.substring(0, 1).toUpperCase() : 'W',
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
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
        border: Border.all(color: primaryMaroon.withValues(alpha: 0.55), width: 1.0),
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