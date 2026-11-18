import 'dart:async';
import 'package:flutter/material.dart';
import 'cart_screen.dart';
import 'customer_home_screen.dart';
import 'data/campus_menu_catalog.dart';
import 'models/cart_item.dart';
import 'services/cart_service.dart';
import 'services/supabase_service.dart';
import 'widgets/responsive_shell.dart';

class CanteenMenuScreen extends StatefulWidget {
  final String canteenName;
  final String categoryName;
  final String? userName;
  final String? idPhotoUrl;
  final ValueChanged<int>? onNavigateToTab;

  const CanteenMenuScreen({
    super.key,
    required this.canteenName,
    required this.categoryName,
    this.userName,
    this.idPhotoUrl,
    this.onNavigateToTab,
  });

  @override
  State<CanteenMenuScreen> createState() => _CanteenMenuScreenState();
}

class _CanteenMenuScreenState extends State<CanteenMenuScreen> {
  static const Color primaryMaroon = DDartTheme.deepMaroon;

  late List<CanteenMenuItem> _items;
  String? _idPhotoUrl;
  String _displayName = '';
  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void initState() {
    super.initState();
    _idPhotoUrl = widget.idPhotoUrl;
    _displayName = widget.userName ?? '';
    _items = CampusMenuCatalog.getItemsByCanteenAndCategory(
      widget.canteenName,
      widget.categoryName,
    );
    if (_items.isEmpty) {
      // Fallback if specific canteen category is empty, fetch general category items
      _items = CampusMenuCatalog.allItems
          .where((i) => i.category.toLowerCase() == widget.categoryName.toLowerCase())
          .toList();
    }
    _loadFromDatabase();
    if (_idPhotoUrl == null || _displayName.isEmpty) {
      _loadProfileAvatar();
    }
  }

  Future<void> _loadProfileAvatar() async {
    try {
      final profile = await SupabaseService().fetchUserProfileModel();
      String? idUrl = _idPhotoUrl;
      if (idUrl == null &&
          profile?.idDocumentPath != null &&
          profile!.idDocumentPath!.isNotEmpty) {
        idUrl = await SupabaseService().getSignedDocumentUrl(profile.idDocumentPath!);
      }
      if (mounted) {
        setState(() {
          if (_displayName.isEmpty && profile != null && profile.firstName.isNotEmpty) {
            _displayName = profile.firstName;
          }
          _idPhotoUrl = idUrl;
        });
      }
    } catch (_) {}
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

  Future<void> _loadFromDatabase() async {
    try {
      final dbItems = await SupabaseService().fetchCanteenMenuItems();
      if (!mounted || dbItems.isEmpty) return;

      final matched = dbItems.where((i) {
        final matchesCat =
            i.category.toLowerCase() == widget.categoryName.toLowerCase();
        final matchesCanteen = i.canteensList.any(
          (c) => c.toLowerCase() == widget.canteenName.toLowerCase(),
        );
        return matchesCat && matchesCanteen;
      }).toList();

      if (matched.isNotEmpty) {
        setState(() {
          _items = matched;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _messenger?.clearSnackBars();
    super.dispose();
  }

  void _showAddToCartSheet(CanteenMenuItem item) {
    int quantity = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final lineTotal = item.price * quantity;

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item.imageUrl != null
                            ? Image.network(
                                item.imageUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _fallbackImage(),
                              )
                            : _fallbackImage(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E1E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.unitDescription,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₱${item.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: primaryMaroon,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Quantity Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quantity',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: quantity > 1
                                  ? () => setSheetState(() => quantity--)
                                  : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '$quantity',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => setSheetState(() => quantity++),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        CartService.instance.addItem(item, quantity: quantity);
                        Navigator.pop(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.clearSnackBars();
                        messenger.showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: primaryMaroon,
                            elevation: 6,
                            duration: const Duration(milliseconds: 1800),
                            dismissDirection: DismissDirection.horizontal,
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Added $quantity x ${item.name} to cart!',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );

                        // Hard timer guarantee that forcibly clears the banner after 2s on all platforms/browsers
                        Timer(const Duration(milliseconds: 2000), () {
                          try {
                            messenger.clearSnackBars();
                          } catch (_) {}
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryMaroon,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Add to Cart • ₱${lineTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey.shade200,
      child: const Icon(Icons.restaurant, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveMobileShell(
      child: Scaffold(
        backgroundColor: Colors.white,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.canteenName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.categoryName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width < 360 ? 2 : 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: MediaQuery.of(context).size.width < 360 ? 0.82 : 0.72,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _buildGridItemCard(item);
                  },
                ),
              ),

              // Bottom Cart Quick Access Bar
              ListenableBuilder(
                listenable: CartService.instance,
                builder: (context, _) {
                  if (CartService.instance.isEmpty) return const SizedBox.shrink();

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
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

  Widget _buildGridItemCard(CanteenMenuItem item) {
    return InkWell(
      onTap: () => _showAddToCartSheet(item),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.grey.shade100,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: item.imageUrl != null
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, _, _) => _cardFallback(),
                      )
                    : _cardFallback(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'serif',
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '₱${item.price.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: primaryMaroon,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardFallback() {
    return Container(
      color: const Color(0xFFFBF4F4),
      child: const Center(
        child: Icon(Icons.fastfood_outlined, color: primaryMaroon, size: 28),
      ),
    );
  }
}
