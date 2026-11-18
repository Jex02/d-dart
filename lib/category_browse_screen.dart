import 'dart:async';
import 'package:flutter/material.dart';
import 'cart_screen.dart';
import 'customer_home_screen.dart';
import 'data/campus_menu_catalog.dart';
import 'models/campus_location.dart';
import 'models/cart_item.dart';
import 'services/cart_service.dart';
import 'services/supabase_service.dart';
import 'widgets/responsive_shell.dart';

class CategoryBrowseScreen extends StatefulWidget {
  final String categoryTitle;
  final String? initialQuery;
  final String? userName;
  final String? idPhotoUrl;
  final ValueChanged<int>? onNavigateToTab;

  const CategoryBrowseScreen({
    super.key,
    required this.categoryTitle,
    this.initialQuery,
    this.userName,
    this.idPhotoUrl,
    this.onNavigateToTab,
  });

  @override
  State<CategoryBrowseScreen> createState() => _CategoryBrowseScreenState();
}

class _CategoryBrowseScreenState extends State<CategoryBrowseScreen> {
  static const Color primaryMaroon = DDartTheme.deepMaroon;

  late List<CanteenMenuItem> _allItems;
  List<CanteenMenuItem> _filteredItems = [];
  String _selectedCanteenFilter = 'All';
  String _selectedCategoryFilter = 'All';
  final _searchController = TextEditingController();
  String? _idPhotoUrl;
  String _displayName = '';
  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  // Stores currently selected canteen for each item id
  final Map<String, String> _itemSelectedCanteen = {};

  // Stores quantity for each item id
  final Map<String, int> _itemQuantities = {};

  bool get _isFullMenuBrowse {
    final lower = widget.categoryTitle.toLowerCase();
    return lower.contains('search') ||
        lower.contains('all') ||
        lower.contains('campus canteen menu');
  }

  @override
  void initState() {
    super.initState();
    _idPhotoUrl = widget.idPhotoUrl;
    _displayName = widget.userName ?? '';
    if (_isFullMenuBrowse) {
      _allItems = CampusMenuCatalog.allItems;
    } else {
      _allItems = CampusMenuCatalog.getItemsByCategory(widget.categoryTitle);
    }
    _filteredItems = List.from(_allItems);

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
    }

    // Initialize default selected canteen and quantities
    for (final item in _allItems) {
      _itemSelectedCanteen[item.id] =
          item.canteensList.isNotEmpty ? item.canteensList.first : item.canteen;
      _itemQuantities[item.id] = 1;
    }

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _applyFilters();
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

      setState(() {
        if (_isFullMenuBrowse) {
          _allItems = dbItems;
        } else {
          _allItems = dbItems
              .where((i) => CampusMenuCatalog.matchesCategory(i.category, widget.categoryTitle))
              .toList();
        }
        for (final item in _allItems) {
          _itemSelectedCanteen.putIfAbsent(
            item.id,
            () => item.canteensList.isNotEmpty ? item.canteensList.first : item.canteen,
          );
          _itemQuantities.putIfAbsent(item.id, () => 1);
        }
        _applyFilters();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _messenger?.clearSnackBars();
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredItems = _allItems.where((item) {
        final matchesQuery = query.isEmpty ||
            item.name.toLowerCase().contains(query) ||
            item.unitDescription.toLowerCase().contains(query);

        final matchesCanteen = _selectedCanteenFilter == 'All' ||
            item.canteensList.any((c) =>
                c.toLowerCase() == _selectedCanteenFilter.toLowerCase());

        final matchesCategory = !_isFullMenuBrowse ||
            _selectedCategoryFilter == 'All' ||
            CampusMenuCatalog.matchesCategory(item.category, _selectedCategoryFilter);

        return matchesQuery && matchesCanteen && matchesCategory;
      }).toList();
    });
  }

  void _addToCart(CanteenMenuItem baseItem) {
    final chosenCanteen =
        _itemSelectedCanteen[baseItem.id] ?? baseItem.canteen;
    final qty = _itemQuantities[baseItem.id] ?? 1;

    final customizedItem = baseItem.copyWith(canteen: chosenCanteen);
    CartService.instance.addItem(customizedItem, quantity: qty);

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
                'Added $qty x ${baseItem.name} ($chosenCanteen) to cart!',
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = DDartTheme.isDark(context);
    final textPrimary = DDartTheme.textPrimary(context);
    final textSecondary = DDartTheme.textSecondary(context);

    return ResponsiveMobileShell(
      child: Scaffold(
        backgroundColor: DDartTheme.scaffoldBg(context),
        appBar: AppBar(
          backgroundColor: primaryMaroon,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.categoryTitle.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 16,
            ),
          ),
          actions: [
            const ThemeToggleButton(iconColor: Colors.white, iconSize: 20),
            ListenableBuilder(
              listenable: CartService.instance,
              builder: (context, _) {
                final count = CartService.instance.totalItemCount;
                return IconButton(
                  tooltip: 'Cart',
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    backgroundColor: Colors.amber,
                    textColor: Colors.black87,
                    child: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  },
                );
              },
            ),
            IconButton(
              tooltip: 'Notifications & Orders',
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () => _navigateToTab(2),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'Profile',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _navigateToTab(3),
                  child: Container(
                    width: 32,
                    height: 32,
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
              // Search & Filter Header Container
              Container(
                color: DDartTheme.surface(context),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: DDartTheme.fieldFill(context),
                        borderRadius: BorderRadius.circular(21),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => _applyFilters(),
                        style: TextStyle(color: textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          icon: Icon(Icons.search, size: 18, color: textSecondary),
                          hintText: 'Search within category...',
                          hintStyle: TextStyle(fontSize: 12, color: DDartTheme.textMuted(context)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Canteen Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          'All',
                          ...CampusLocation.officialCanteens,
                        ].map((canteen) {
                          final isSelected = _selectedCanteenFilter == canteen;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                canteen == 'All' ? 'All Canteens' : canteen,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : textPrimary,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: primaryMaroon,
                              backgroundColor: DDartTheme.cardSubtle(context),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedCanteenFilter = canteen);
                                  _applyFilters();
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    if (_isFullMenuBrowse) ...[
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            'All',
                            ...CampusMenuCatalog.categories,
                          ].map((cat) {
                            final isSelected = _selectedCategoryFilter == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  cat == 'All' ? 'All Categories' : cat,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? DDartTheme.accentText(context) : textPrimary,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: (isDark ? DDartTheme.brightGold : primaryMaroon)
                                    .withValues(alpha: 0.16),
                                backgroundColor: DDartTheme.cardSubtle(context),
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedCategoryFilter = cat);
                                    _applyFilters();
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Items List
              Expanded(
                child: _filteredItems.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          return _buildItemCard(item);
                        },
                      ),
              ),

              // Bottom Cart Bar
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No items found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search query or canteen filter.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(CanteenMenuItem item) {
    final selectedCanteen =
        _itemSelectedCanteen[item.id] ?? item.canteensList.first;
    final qty = _itemQuantities[item.id] ?? 1;
    final textPrimary = DDartTheme.textPrimary(context);
    final textSecondary = DDartTheme.textSecondary(context);
    final accent = DDartTheme.accentText(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DDartTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DDartTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Food Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 76,
                  height: 76,
                  color: DDartTheme.cardSubtle(context),
                  child: item.imageUrl != null
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: DDartTheme.cardSubtle(context),
                            child: const Icon(Icons.fastfood, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: DDartTheme.cardSubtle(context),
                          child: const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Title, Unit Description & Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.unitDescription,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₱${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Dropdown showing which canteen it is available at
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                'Available at:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: DDartTheme.maroonTint(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: item.canteensList.contains(selectedCanteen)
                          ? selectedCanteen
                          : item.canteensList.first,
                      isExpanded: true,
                      dropdownColor: DDartTheme.card(context),
                      icon: Icon(Icons.arrow_drop_down, color: accent),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      items: item.canteensList.map((canteen) {
                        return DropdownMenuItem<String>(
                          value: canteen,
                          child: Text(
                            canteen,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (newCanteen) {
                        if (newCanteen != null) {
                          setState(() {
                            _itemSelectedCanteen[item.id] = newCanteen;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quantity controls and "Add to Cart" button
          Row(
            children: [
              // Quantity Picker
              Container(
                decoration: BoxDecoration(
                  color: DDartTheme.cardSubtle(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DDartTheme.border(context)),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: qty > 1
                          ? () => setState(() => _itemQuantities[item.id] = qty - 1)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.remove,
                          size: 14,
                          color: qty > 1 ? textPrimary : DDartTheme.textMuted(context),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '$qty',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _itemQuantities[item.id] = qty + 1),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(Icons.add, size: 14, color: textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Add to Cart Button
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () => _addToCart(item),
                    icon: const Icon(Icons.add_shopping_cart, size: 16, color: Colors.white),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Add to Cart • ₱${(item.price * qty).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}
