import 'package:flutter/material.dart';
import 'canteen_menu_screen.dart';
import 'cart_screen.dart';
import 'customer_home_screen.dart';
import 'services/cart_service.dart';
import 'services/supabase_service.dart';
import 'widgets/responsive_shell.dart';

class CanteenCategoryScreen extends StatefulWidget {
  final String canteenName;
  final String? userName;
  final String? idPhotoUrl;
  final ValueChanged<int>? onNavigateToTab;

  const CanteenCategoryScreen({
    super.key,
    required this.canteenName,
    this.userName,
    this.idPhotoUrl,
    this.onNavigateToTab,
  });

  @override
  State<CanteenCategoryScreen> createState() => _CanteenCategoryScreenState();
}

class _CanteenCategoryScreenState extends State<CanteenCategoryScreen> {
  static const Color primaryMaroon = DDartTheme.deepMaroon;
  String _displayName = 'Student';
  String? _idPhotoUrl;

  @override
  void initState() {
    super.initState();
    _idPhotoUrl = widget.idPhotoUrl;
    if (widget.userName != null && widget.userName!.isNotEmpty) {
      _displayName = widget.userName!;
    }
    if (widget.userName == null || widget.userName!.isEmpty || _idPhotoUrl == null) {
      _loadUserProfile();
    }
  }

  Future<void> _loadUserProfile() async {
    final profile = await SupabaseService().fetchUserProfileModel();
    String? idUrl = _idPhotoUrl;
    if (idUrl == null &&
        profile?.idDocumentPath != null &&
        profile!.idDocumentPath!.isNotEmpty) {
      idUrl = await SupabaseService().getSignedDocumentUrl(profile.idDocumentPath!);
    }
    if (mounted) {
      setState(() {
        if (profile != null && profile.firstName.isNotEmpty) {
          _displayName = profile.firstName;
        }
        _idPhotoUrl = idUrl;
      });
    }
  }

  void _navigateToTab(int tabIndex) {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(tabIndex);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CustomerHomeScreen(initialTabIndex: tabIndex),
      ),
    );
  }

  void _openCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CanteenMenuScreen(
          canteenName: widget.canteenName,
          categoryName: category,
          userName: _displayName,
          idPhotoUrl: _idPhotoUrl,
          onNavigateToTab: widget.onNavigateToTab,
        ),
      ),
    );
  }

  Widget _buildHeaderAvatarFallback() {
    final initial =
        _displayName.isNotEmpty ? _displayName.substring(0, 1).toUpperCase() : 'W';
    return CircleAvatar(
      radius: 15,
      backgroundColor: DDartTheme.brightGold.withValues(alpha: 0.25),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = DDartTheme.surface(context);
    final textPrimary = DDartTheme.textPrimary(context);
    final accent = DDartTheme.accentText(context);

    return ResponsiveMobileShell(
      child: Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          backgroundColor: primaryMaroon,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'D-DART',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              fontSize: 18,
            ),
          ),
          actions: [
            const ThemeToggleButton(iconColor: Colors.white, iconSize: 21),
            IconButton(
              tooltip: 'Notifications & Orders',
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () => _navigateToTab(2),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Tooltip(
                message: 'Profile',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _navigateToTab(3),
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
                              errorBuilder: (_, _, _) => _buildHeaderAvatarFallback(),
                            )
                          : _buildHeaderAvatarFallback(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting Header (per Wireframe 2)
                      Text(
                        'Good day!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                          color: textPrimary,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        '$_displayName!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Canteen Name Header (e.g. MAIN CANTEEN)
                      Text(
                        widget.canteenName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Popular Categories Subheader
                      Center(
                        child: Text(
                          'Popular categories',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'serif',
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Category 1 & 2 in a Row (Food and snacks & Beverages)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: _buildCategoryCard(
                              title: 'Food and snacks',
                              icon: Icons.fastfood_rounded,
                              iconColor: const Color(0xFFE67E22),
                              circleBg: const Color(0xFFFDEBD0),
                              onTap: () => _openCategory('Food and snacks'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildCategoryCard(
                              title: 'Beverages',
                              icon: Icons.local_drink_rounded,
                              iconColor: Colors.white,
                              circleBg: const Color(0xFFE67E22),
                              onTap: () => _openCategory('Beverages'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Category 3 (Desserts) Centered Below
                      Center(
                        child: SizedBox(
                          width: 170,
                          child: _buildCategoryCard(
                            title: 'Desserts',
                            icon: Icons.icecream_rounded,
                            iconColor: const Color(0xFFC0392B),
                            circleBg: const Color(0xFFFADBD8),
                            onTap: () => _openCategory('Desserts'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Floating Cart Summary Bar if cart has items
              ListenableBuilder(
                listenable: CartService.instance,
                builder: (context, _) {
                  if (CartService.instance.isEmpty) return const SizedBox.shrink();

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: DDartTheme.surface(context),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CartScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: primaryMaroon,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Badge(
                              label: Text('${CartService.instance.totalItemCount}'),
                              backgroundColor: Colors.white,
                              textColor: primaryMaroon,
                              child: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'View Cart',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Text(
                              '₱${CartService.instance.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color circleBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: circleBg,
              boxShadow: [
                BoxShadow(
                  color: circleBg.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 52, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'serif',
              color: DDartTheme.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
