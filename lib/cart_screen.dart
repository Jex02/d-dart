import 'package:flutter/material.dart';
import 'models/campus_location.dart';
import 'models/cart_item.dart';
import 'mock_data.dart';
import 'order_tracking_screen.dart';
import 'services/cart_service.dart';
import 'services/duty_lock_service.dart';
import 'services/supabase_service.dart';
import 'widgets/responsive_shell.dart';

class CartScreen extends StatefulWidget {
  final bool isEmbeddedTab;
  final VoidCallback? onSwitchToHome;

  const CartScreen({
    super.key,
    this.isEmbeddedTab = false,
    this.onSwitchToHome,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const Color primaryMaroon = Color(0xFF6B1D16);
  static const Color cardBgColor = Color(0xFFF6F6F6);
  static const Color buttonPeachBg = Color(0xFFEAD9D7);

  List<String> _dropoffLocations =
      CampusLocation.defaultDropoffs.map((l) => l.name).toList();
  String _selectedDropoff = 'Allied';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });
    _loadDropoffLocations();
  }

  Future<void> _loadDropoffLocations() async {
    try {
      final dropoffs = await SupabaseService().fetchLocations('dropoff');
      if (dropoffs.isNotEmpty && mounted) {
        setState(() {
          _dropoffLocations = dropoffs.map((l) => l.name).toList();
          if (!_dropoffLocations.contains(_selectedDropoff)) {
            _selectedDropoff = _dropoffLocations.first;
          }
        });
      }
    } catch (_) {}
  }

  void _showCheckoutSheet() {
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: DDartTheme.card(ctx),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: DDartTheme.divider(ctx),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Campus Delivery Drop-off',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: DDartTheme.textPrimary(ctx),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Drop-off Building Selector
                  Text(
                    'Drop-off Location',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DDartTheme.textPrimary(ctx),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDropoff,
                    dropdownColor: DDartTheme.card(ctx),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: DDartTheme.cardSubtle(ctx),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: DDartTheme.border(ctx)),
                      ),
                    ),
                    items: _dropoffLocations.map((loc) {
                      return DropdownMenuItem(value: loc, child: Text(loc));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => _selectedDropoff = val);
                        setState(() => _selectedDropoff = val);
                      }
                    },
                  ),
                  StatefulBuilder(
                    builder: (context, setSheetState) {
                      final activeCanteens = CartService.instance.activeCanteens;
                      final fees = CartService.instance.getDeliveryFeesForDestination(_selectedDropoff);
                      final totalFee = CartService.instance.calculateDeliveryFeeTo(_selectedDropoff);
                      final hasMissingDistance = totalFee == null;
                      final grandTotal = (totalFee != null)
                          ? (CartService.instance.subtotal + totalFee)
                          : null;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasMissingDistance)
                            Container(
                              margin: const EdgeInsets.only(top: 8, bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Delivery route unavailable for the selected destination. Please choose another delivery building.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Distance & Canteen Breakdown
                          Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...activeCanteens.map((canteen) {
                                  final dist = CartService.instance.getDistanceForCanteen(
                                    canteen,
                                    _selectedDropoff,
                                  );
                                  final fee = fees[canteen];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.straighten,
                                          size: 13,
                                          color: DDartTheme.primaryMaroon,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            dist != null
                                                ? '$canteen → $_selectedDropoff (${CampusLocation.formatDistance(dist)} • ₱${fee?.toStringAsFixed(2) ?? 'N/A'})'
                                                : '$canteen → $_selectedDropoff (Route unavailable)',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: dist != null
                                                  ? Colors.grey.shade700
                                                  : Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Delivery Notes Field
                          Text(
                            'Special Instructions (Optional)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: DDartTheme.textPrimary(ctx),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: notesController,
                            decoration: InputDecoration(
                              hintText: 'e.g. 3rd floor CS Lab, call when near',
                              filled: true,
                              fillColor: DDartTheme.cardSubtle(ctx),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: DDartTheme.border(ctx)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Order Summary Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: DDartTheme.maroonTint(ctx),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: DDartTheme.accentText(ctx).withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Food Subtotal:', style: TextStyle(fontSize: 12.5)),
                                    Text(
                                      '₱${CartService.instance.subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      activeCanteens.length > 1
                                          ? 'Campus Delivery Fee (${activeCanteens.length} canteens):'
                                          : 'Campus Delivery Fee:',
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                    Text(
                                      totalFee != null
                                          ? '₱${totalFee.toStringAsFixed(2)}'
                                          : 'Unavailable',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: totalFee != null
                                            ? DDartTheme.textPrimary(ctx)
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Amount to Pay:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      grandTotal != null
                                          ? '₱${grandTotal.toStringAsFixed(2)}'
                                          : 'Unavailable',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: grandTotal != null
                                            ? DDartTheme.accentText(ctx)
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Payment Mode: Direct Cash or personal GCash to runner on handover.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: DDartTheme.textSecondary(ctx),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Confirm and Place Order Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: (_isSubmitting || hasMissingDistance)
                                  ? null
                                  : () async {
                                      Navigator.pop(ctx);
                                      await _placeOrder(notesController.text.trim());
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryMaroon,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Confirm and Place Pabili Order',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _placeOrder(String instructions) async {
    if (CartService.instance.isEmpty) return;

    setState(() => _isSubmitting = true);

    final description = CartService.instance.generateOrderDescription();
    final pickup = CartService.instance.primaryCanteen;
    final estimatedPrice = CartService.instance.subtotal;
    final deliveryFee =
        CartService.instance.calculateDeliveryFeeTo(_selectedDropoff) ??
            CartService.instance.totalProcessingFee;
    final config = DutyLockService.activeConfig;

    String createdId;
    try {
      final inserted = await SupabaseService().createOrder(
        pickup: pickup,
        dropoff: _selectedDropoff,
        description: description,
        price: estimatedPrice,
        deliveryFee: deliveryFee,
        instructions: instructions,
        expiresIn: Duration(minutes: config.requestExpirationMinutes),
      );
      createdId = inserted['id'].toString();

      addPabiliRequest(
        orderId: createdId,
        verificationCode: inserted['verification_code']?.toString(),
        customerId: inserted['customer_id']?.toString(),
        pickup: pickup,
        dropoff: _selectedDropoff,
        description: description,
        price: estimatedPrice,
        deliveryFee: deliveryFee,
        instructions: instructions,
        expiresIn: Duration(minutes: config.requestExpirationMinutes),
      );
    } catch (_) {
      final fallback = addPabiliRequest(
        pickup: pickup,
        dropoff: _selectedDropoff,
        description: description,
        price: estimatedPrice,
        deliveryFee: deliveryFee,
        instructions: instructions,
        expiresIn: Duration(minutes: config.requestExpirationMinutes),
      );
      createdId = fallback['id'].toString();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }

    CartService.instance.clearCart();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: primaryMaroon,
          content: Text('Pabili request created successfully!'),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(
            orderId: createdId,
            isRunner: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenContent = Scaffold(
      backgroundColor: DDartTheme.surface(context),
      body: SafeArea(
        child: Column(
          children: [
            // Maroon Header Banner (per Wireframe 1)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                color: primaryMaroon,
              ),
              child: const Text(
                'My Cart',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            // Back arrow bar if not embedded tab
            if (!widget.isEmbeddedTab)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: DDartTheme.textPrimary(context)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              )
            else
              const SizedBox(height: 12),

            // Main Cart Content
            Expanded(
              child: ListenableBuilder(
                listenable: CartService.instance,
                builder: (context, _) {
                  final items = CartService.instance.items;

                  if (items.isEmpty) {
                    return _buildEmptyCartView();
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cart Item Cards List
                        ...items.map(_buildCartItemCard),
                        const SizedBox(height: 20),

                        // Price Details Section (per Wireframe 1)
                        _buildPriceDetailsSection(),
                        const SizedBox(height: 28),

                        // "Continue" Button (per Wireframe 1)
                        Center(
                          child: SizedBox(
                            width: 140,
                            height: 38,
                            child: ElevatedButton(
                              onPressed: _showCheckoutSheet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonPeachBg,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'Continue',
                                style: TextStyle(
                                  color: Color(0xFF222222),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    return widget.isEmbeddedTab
        ? screenContent
        : ResponsiveMobileShell(child: screenContent);
  }

  Widget _buildEmptyCartView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: DDartTheme.cardSubtle(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 46,
                color: DDartTheme.textMuted(context),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: DDartTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse campus canteens to add food, drinks, and snacks to your cart.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: DDartTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 20),
            if (widget.onSwitchToHome != null)
              ElevatedButton.icon(
                onPressed: widget.onSwitchToHome,
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Browse Canteens'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryMaroon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemCard(CartItem cartItem) {
    final item = cartItem.item;
    final textPrimary = DDartTheme.textPrimary(context);
    final textSecondary = DDartTheme.textSecondary(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DDartTheme.cardSubtle(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DDartTheme.border(context)),
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Food Thumbnail (Rounded Square)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 72,
                  height: 72,
                  color: DDartTheme.card(context),
                  child: item.imageUrl != null
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _cardItemFallback(),
                        )
                      : _cardItemFallback(),
                ),
              ),
              const SizedBox(width: 12),

              // Title, Subtitle, Qty
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 28),
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.unitDescription,
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quantity Row with increment/decrement
                    Row(
                      children: [
                        Text(
                          'Qty: ${cartItem.quantity}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: () =>
                              CartService.instance.decrementQuantity(item.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: DDartTheme.card(context),
                              shape: BoxShape.circle,
                              border: Border.all(color: DDartTheme.border(context)),
                            ),
                            child: Icon(Icons.remove, size: 14, color: textPrimary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () =>
                              CartService.instance.incrementQuantity(item.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: DDartTheme.card(context),
                              shape: BoxShape.circle,
                              border: Border.all(color: DDartTheme.border(context)),
                            ),
                            child: Icon(Icons.add, size: 14, color: textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Remove Button 'x' at Top Right
          Positioned(
            top: 0,
            right: 0,
            child: InkWell(
              onTap: () => CartService.instance.removeItem(item.id),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: textPrimary,
                ),
              ),
            ),
          ),

          // Line Total at Bottom Right: "TOTAL : 60"
          Positioned(
            bottom: 2,
            right: 4,
            child: Text(
              'TOTAL : ${cartItem.totalPrice.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardItemFallback() {
    return Container(
      color: DDartTheme.cardSubtle(context),
      child: const Center(
        child: Icon(Icons.fastfood, size: 28, color: Colors.grey),
      ),
    );
  }

  Widget _buildPriceDetailsSection() {
    final subtotal = CartService.instance.subtotal;
    final activeCanteens = CartService.instance.activeCanteens;
    final fees = CartService.instance.getDeliveryFeesForDestination(_selectedDropoff);
    final totalFee = CartService.instance.calculateDeliveryFeeTo(_selectedDropoff);
    final orderTotal = totalFee != null ? (subtotal + totalFee) : CartService.instance.orderTotal;
    final textPrimary = DDartTheme.textPrimary(context);
    final textSecondary = DDartTheme.textSecondary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 14),

        // Total Product Price
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Product Price:',
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            Text(
              subtotal.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Processing Fee Breakdown per Canteen
        Text(
          activeCanteens.length > 1
              ? 'Campus Delivery Fee (${activeCanteens.length} canteens to $_selectedDropoff)'
              : 'Campus Delivery Fee (to $_selectedDropoff)',
          style: TextStyle(
            fontSize: 13,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 6),

        if (activeCanteens.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Standard Base Fee:',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
                Text(
                  '0',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          )
        else
          ...activeCanteens.map((canteen) {
            final dist = CartService.instance.getDistanceForCanteen(canteen, _selectedDropoff);
            final fee = fees[canteen];
            final distStr = dist != null ? ' (${CampusLocation.formatDistance(dist)})' : '';
            return Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$canteen$distStr:',
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary,
                    ),
                  ),
                  Text(
                    fee != null ? fee.toStringAsFixed(0) : 'N/A',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 12),

        // Order Total
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Order Total:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            Text(
              orderTotal.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
