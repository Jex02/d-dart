import 'package:flutter/material.dart';
import 'cart_screen.dart';
import 'data/campus_menu_catalog.dart';
import 'models/cart_item.dart';
import 'services/cart_service.dart';
import 'widgets/responsive_shell.dart';

class CategoryBrowseScreen extends StatefulWidget {
  final String categoryTitle;
  final String? initialQuery;

  const CategoryBrowseScreen({
    super.key,
    required this.categoryTitle,
    this.initialQuery,
  });

  @override
  State<CategoryBrowseScreen> createState() => _CategoryBrowseScreenState();
}

class _CategoryBrowseScreenState extends State<CategoryBrowseScreen> {
  static const Color primaryMaroon = DDartTheme.deepMaroon;

  late List<CanteenMenuItem> _allItems;
  List<CanteenMenuItem> _filteredItems = [];
  String _selectedCanteenFilter = 'All';
  final _searchController = TextEditingController();

  // Stores currently selected canteen for each item id
  final Map<String, String> _itemSelectedCanteen = {};

  // Stores quantity for each item id
  final Map<String, int> _itemQuantities = {};

  @override
  void initState() {
    super.initState();
    final isGeneralSearch = widget.categoryTitle.toLowerCase().contains('search') ||
        widget.categoryTitle.toLowerCase().contains('all');

    if (isGeneralSearch) {
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
  }

  @override
  void dispose() {
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

        return matchesQuery && matchesCanteen;
      }).toList();
    });
  }

  void _addToCart(CanteenMenuItem baseItem) {
    final chosenCanteen =
        _itemSelectedCanteen[baseItem.id] ?? baseItem.canteen;
    final qty = _itemQuantities[baseItem.id] ?? 1;

    final customizedItem = baseItem.copyWith(canteen: chosenCanteen);
    CartService.instance.addItem(customizedItem, quantity: qty);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: primaryMaroon,
        content: Text('Added $qty x ${baseItem.name} ($chosenCanteen) to cart!'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'View Cart',
          textColor: Colors.amber,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveMobileShell(
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9FB),
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
            ListenableBuilder(
              listenable: CartService.instance,
              builder: (context, _) {
                final count = CartService.instance.totalItemCount;
                return IconButton(
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
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Search & Filter Header Container
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2ECEC),
                        borderRadius: BorderRadius.circular(21),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => _applyFilters(),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          icon: Icon(Icons.search, size: 18, color: Colors.black54),
                          hintText: 'Search within category...',
                          hintStyle: TextStyle(fontSize: 12, color: Colors.black45),
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
                          'Main Canteen',
                          'College Canteen',
                          'Elementary Canteen'
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
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: primaryMaroon,
                              backgroundColor: Colors.grey.shade100,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
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
                  color: Colors.grey.shade100,
                  child: item.imageUrl != null
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.fastfood, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.unitDescription,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₱${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: primaryMaroon,
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
              const Icon(Icons.storefront_outlined, size: 16, color: primaryMaroon),
              const SizedBox(width: 6),
              const Text(
                'Available at:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryMaroon.withValues(alpha: 0.25)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: item.canteensList.contains(selectedCanteen)
                          ? selectedCanteen
                          : item.canteensList.first,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: primaryMaroon),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1E1E),
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
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
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
                          color: qty > 1 ? Colors.black87 : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '$qty',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _itemQuantities[item.id] = qty + 1),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(Icons.add, size: 14, color: Colors.black87),
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
                    label: Text(
                      'Add to Cart • ₱${(item.price * qty).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12.5,
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}
