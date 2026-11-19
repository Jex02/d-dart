import 'package:flutter/material.dart';
import 'canteen_category_screen.dart';
import 'cart_screen.dart';
import 'category_browse_screen.dart';
import 'cor_upload_screen.dart';
import 'login.dart';
import 'main_dashboard.dart';
import 'models/delivery_order.dart';
import 'models/problem_report.dart';
import 'models/user_profile.dart';
import 'order_tracking_screen.dart';
import 'services/cart_service.dart';
import 'services/duty_lock_service.dart';
import 'services/supabase_service.dart';
import 'services/theme_service.dart';
import 'widgets/cor_timetable_dialog.dart';
import 'widgets/responsive_shell.dart';

class CustomerHomeScreen extends StatefulWidget {
  final int initialTabIndex;

  const CustomerHomeScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  late int _selectedIndex;
  UserProfile? _profile;
  String? _idPhotoUrl;
  final _searchController = TextEditingController();
  late Stream<List<Map<String, dynamic>>> _customerOrdersStream;

  static const Color primaryMaroon = DDartTheme.deepMaroon;
  static const Color accentGold = DDartTheme.brightGold;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex.clamp(0, 3);
    _customerOrdersStream =
        SupabaseService().streamCustomerOrders().asBroadcastStream();
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

  void _openOrderTracking(String orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(orderId: orderId, isRunner: false),
      ),
    ).then((_) => _loadProfileAndExpireStale());
  }

  void _navigateToTabFromChild(int tabIndex) {
    final selfRoute = ModalRoute.of(context);
    Navigator.of(context).popUntil((route) => route == selfRoute || route.isFirst);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      setState(() => _selectedIndex = tabIndex.clamp(0, 3));
      _loadProfileAndExpireStale();
    }
  }

  void _openCanteenCategory(String canteenName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CanteenCategoryScreen(
          canteenName: canteenName,
          userName: _profile?.firstName,
          idPhotoUrl: _idPhotoUrl,
          onNavigateToTab: _navigateToTabFromChild,
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
          userName: _profile?.firstName,
          idPhotoUrl: _idPhotoUrl,
          onNavigateToTab: _navigateToTabFromChild,
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
          userName: _profile?.firstName,
          idPhotoUrl: _idPhotoUrl,
          onNavigateToTab: _navigateToTabFromChild,
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
          title: const Text('Report a Problem / Support'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Issue Category',
                  border: OutlineInputBorder(),
                ),
                items: ProblemReport.customerCategories
                    .map((key) => DropdownMenuItem(
                          value: key,
                          child: Text(ProblemReport.categoryLabels[key] ?? key),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => category = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Describe the issue in detail',
                  hintText: 'Provide details so the Super Admin can review and resolve it...',
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
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
    final text = descCtrl.text.trim();
    descCtrl.dispose();
    if (submit == true && text.isNotEmpty) {
      try {
        await SupabaseService().submitProblemReport(
          category: category,
          description: text,
          reporterRole: 'customer',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Problem report submitted to Super Administrators.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Could not submit report: $e'),
            ),
          );
        }
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
                    const ThemeToggleButton(iconColor: Colors.white, iconSize: 22),
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
                decoration: BoxDecoration(
                  color: DDartTheme.surface(context),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
          color: DDartTheme.surface(context),
          border: Border(top: BorderSide(color: DDartTheme.divider(context), width: 0.8)),
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
              backgroundColor: DDartTheme.surface(context),
              selectedItemColor: DDartTheme.accentText(context),
              unselectedItemColor: DDartTheme.textMuted(context),
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
    final textPrimary = DDartTheme.textPrimary(context);
    final textSecondary = DDartTheme.textSecondary(context);
    final accent = DDartTheme.accentText(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good day,',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
              color: textPrimary,
              height: 1.1,
            ),
          ),
          Text(
            '$firstName!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'What would you like delivered on campus today?',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'serif',
              fontStyle: FontStyle.italic,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 14),

          Container(
            height: 44,
            decoration: BoxDecoration(
              color: DDartTheme.fieldFill(context),
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: textPrimary, fontSize: 13),
              onSubmitted: (query) {
                final trimmed = query.trim();
                _searchController.clear();
                if (trimmed.isNotEmpty) {
                  _openSearchResults(trimmed);
                }
              },
              decoration: InputDecoration(
                border: InputBorder.none,
                icon: Icon(Icons.search, size: 18, color: textSecondary),
                hintText: 'Request food, drinks, or school supplies...',
                hintStyle: TextStyle(fontSize: 12, color: DDartTheme.textMuted(context)),
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
                  iconWidget: Icon(
                    Icons.local_drink,
                    size: 32,
                    color: DDartTheme.isDark(context)
                        ? const Color(0xFF7FB3D5)
                        : const Color(0xFF2C3E50),
                  ),
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
            children: [
              Text(
                'Choose Pickup Canteen',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
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
                  onTap: () => _openCanteenCategory('Main Canteen'),
                  child: Image.asset(
                    'assets/main_canteen.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: DDartTheme.cardSubtle(context),
                      child: const Icon(Icons.restaurant, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCanteenCard(
                  label: 'Highschool\nCanteen',
                  onTap: () => _openCanteenCategory('Highschool Canteen'),
                  child: Image.asset(
                    'assets/highschool_canteen.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: DDartTheme.cardSubtle(context),
                      child: Icon(Icons.fastfood_outlined, color: accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCanteenCard(
                  label: 'Mini Canteen',
                  onTap: () => _openCanteenCategory('Mini Canteen'),
                  child: Image.asset(
                    'assets/mini_canteen.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: DDartTheme.cardSubtle(context),
                      child: Icon(Icons.storefront_outlined, color: accent),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          Text(
            'Quick Actions & Live Tracking',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimary,
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
                      onTap: () => _openCategoryBrowse('Campus Canteen Menu'),
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
      stream: _customerOrdersStream,
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
        final accent = DDartTheme.accentText(context);
        final textPrimary = DDartTheme.textPrimary(context);
        final textSecondary = DDartTheme.textSecondary(context);

        return InkWell(
          onTap: activeOrder != null
              ? () => _openOrderTracking(activeOrder.id)
              : () => setState(() => _selectedIndex = 2),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 126,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: DDartTheme.card(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: activeOrder != null ? accent : DDartTheme.outlineBorder(context),
                width: activeOrder != null ? 1.4 : 0.8,
              ),
            ),
            child: activeOrder == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RUNNER UPDATE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: textPrimary,
                        ),
                      ),
                      Icon(Icons.local_shipping_outlined, size: 38, color: textSecondary),
                      Text(
                        'No active orders.\nTap to create one!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: DDartTheme.textMuted(context)),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LIVE: ${activeStatus.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                      if (showOtp)
                        Text(
                          'OTP: ${activeOrder.verificationCode}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                            color: accent,
                          ),
                        )
                      else
                        Text(
                          'Tap to Track Live',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                      Text(
                        activeOrder.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10.5, color: textPrimary),
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
      stream: _customerOrdersStream,
      builder: (context, snapshot) {
        final orders = (snapshot.data ?? []).map(DeliveryOrder.fromJson).toList();
        if (orders.isEmpty) {
          return const Center(
            child: Text(
              'You have not placed any campus delivery orders yet.\nBrowse a canteen on Home to get started!',
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

              final accent = DDartTheme.accentText(context);
              final textSecondary = DDartTheme.textSecondary(context);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: DDartTheme.card(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: DDartTheme.border(context)),
                ),
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
                                    ? accent.withValues(alpha: 0.16)
                                    : DDartTheme.cardSubtle(context),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? accent : textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              'Total ₱${order.totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          order.description,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: DDartTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.pickupLocation} → ${order.dropoffLocation}',
                          style: TextStyle(fontSize: 12, color: textSecondary),
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: accent,
                                  fontSize: 11.5,
                                ),
                              ),
                              Text(
                                'Tap to Track →',
                                style: TextStyle(fontSize: 11, color: textSecondary),
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
    final isDark = DDartTheme.isDark(context);
    final cardColor = DDartTheme.card(context);
    final borderColor = DDartTheme.border(context);
    final textPrimary = DDartTheme.textPrimary(context);
    final textSecondary = DDartTheme.textSecondary(context);
    final accent = DDartTheme.accentText(context);

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
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: borderColor),
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
                          border: Border.all(color: cardColor, width: 2),
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'serif',
                  color: textPrimary,
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
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '🎓 ${profile?.accountTypeLabel ?? 'Student'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (profile?.isVerified ?? false)
                          ? (isDark ? Colors.green.withValues(alpha: 0.18) : Colors.green.shade50)
                          : (isDark ? Colors.amber.withValues(alpha: 0.18) : Colors.amber.shade50),
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
                            ? (isDark ? Colors.green.shade300 : Colors.green.shade800)
                            : (isDark ? Colors.amber.shade300 : Colors.amber.shade900),
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
                  Icon(Icons.badge_outlined, size: 15, color: textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    profile?.studentId.isNotEmpty == true ? profile!.studentId : 'CIT-U Student',
                    style: TextStyle(fontSize: 12.5, color: textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 14),
                  Icon(Icons.email_outlined, size: 15, color: textSecondary),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      profile?.email ?? SupabaseService().currentUser?.email ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: textSecondary),
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
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 18, color: accent),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Enrolled Class Schedule',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasVerifiedCor
                            ? (isDark ? Colors.green.withValues(alpha: 0.18) : Colors.green.shade50)
                            : (isDark ? Colors.orange.withValues(alpha: 0.18) : Colors.orange.shade50),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasVerifiedCor ? Colors.green.shade400 : Colors.orange.shade400,
                        ),
                      ),
                      child: Text(
                        hasVerifiedCor
                            ? '${DutyLockService.verifiedSchedule.length} Sessions'
                            : 'No COR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasVerifiedCor
                              ? (isDark ? Colors.green.shade300 : Colors.green.shade800)
                              : (isDark ? Colors.orange.shade300 : Colors.orange.shade900),
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
                  style: TextStyle(fontSize: 12, color: textSecondary),
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
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeService.instance.themeModeNotifier,
                builder: (context, mode, _) {
                  final darkEnabled = mode == ThemeMode.dark;
                  return SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        darkEnabled ? Icons.dark_mode : Icons.light_mode_outlined,
                        color: accent,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      darkEnabled ? 'Dark theme enabled' : 'Light theme enabled',
                      style: TextStyle(fontSize: 11.5, color: textSecondary),
                    ),
                    activeThumbColor: accentGold,
                    activeTrackColor: primaryMaroon,
                    value: darkEnabled,
                    onChanged: (val) => ThemeService.instance.setDarkMode(val),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              if (canSwitchToRunner) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.swap_horiz, color: accent, size: 20),
                  ),
                  title: Text('Switch Mode (Customer / Runner)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPrimary)),
                  subtitle: Text('Accept gigs and deliver for peers on campus', style: TextStyle(fontSize: 11.5, color: textSecondary)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: textSecondary),
                  onTap: _switchMode,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.school_outlined, color: accent, size: 20),
                  ),
                  title: Text('Manage COR / Study Load', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPrimary)),
                  subtitle: Text('Re-upload or adjust class schedule', style: TextStyle(fontSize: 11.5, color: textSecondary)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: textSecondary),
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
                    color: Colors.amber.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.report_problem_outlined, color: Colors.amber, size: 20),
                ),
                title: Text('Report a Problem / Support', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPrimary)),
                subtitle: Text('Submit delivery disputes or app feedback', style: TextStyle(fontSize: 11.5, color: textSecondary)),
                trailing: Icon(Icons.arrow_forward_ios, size: 14, color: textSecondary),
                onTap: _openGeneralReportDialog,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.red.withValues(alpha: 0.18) : Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                ),
                title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent, fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.redAccent),
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
              color: DDartTheme.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DDartTheme.outlineBorder(context), width: 0.9),
            ),
            alignment: Alignment.center,
            child: iconWidget,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: DDartTheme.accentText(context),
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
              color: DDartTheme.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DDartTheme.outlineBorder(context), width: 0.9),
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
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: DDartTheme.accentText(context),
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label) {
    final accent = DDartTheme.accentText(context);
    return Container(
      width: double.infinity,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: DDartTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: accent,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          Icon(Icons.arrow_forward, size: 14, color: DDartTheme.textPrimary(context)),
        ],
      ),
    );
  }
}