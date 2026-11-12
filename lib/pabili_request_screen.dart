import 'package:flutter/material.dart';
import 'models/campus_location.dart';
import 'models/system_config.dart';
import 'order_tracking_screen.dart';
import 'services/duty_lock_service.dart';
import 'services/supabase_service.dart';
import 'mock_data.dart';
import 'utils/validators.dart';

class PabiliRequestScreen extends StatefulWidget {
  final String? initialPickup;
  final String? initialHint;

  const PabiliRequestScreen({
    super.key,
    this.initialPickup,
    this.initialHint,
  });

  @override
  State<PabiliRequestScreen> createState() => _PabiliRequestScreenState();
}

class _PabiliRequestScreenState extends State<PabiliRequestScreen> {
  static const Color primaryMaroon = Color(0xFF7F0000);

  final _formKey = GlobalKey<FormState>();
  final _itemController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSubmitting = false;
  SystemConfig _config = DutyLockService.activeConfig;

  List<String> _pickupLocations =
      CampusLocation.defaultPickups.map((l) => l.name).toList();
  List<String> _dropoffLocations =
      CampusLocation.defaultDropoffs.map((l) => l.name).toList();

  late String _selectedPickup;
  late String _selectedDropoff;

  @override
  void initState() {
    super.initState();
    _selectedPickup = (widget.initialPickup != null &&
            _pickupLocations.contains(widget.initialPickup))
        ? widget.initialPickup!
        : _pickupLocations.first;
    _selectedDropoff = _dropoffLocations.first;
    if (widget.initialHint != null && widget.initialHint!.isNotEmpty) {
      _itemController.text = widget.initialHint!;
    }
    _loadLocationsAndConfig();
  }

  Future<void> _loadLocationsAndConfig() async {
    final pickups = await SupabaseService().fetchLocations('pickup');
    final dropoffs = await SupabaseService().fetchLocations('dropoff');
    final config = await SupabaseService().fetchSystemConfig();
    if (!mounted) return;

    setState(() {
      _config = config;
      _pickupLocations = pickups.map((l) => l.name).toList();
      _dropoffLocations = dropoffs.map((l) => l.name).toList();
      if (!_pickupLocations.contains(_selectedPickup) && _pickupLocations.isNotEmpty) {
        _selectedPickup = _pickupLocations.first;
      }
      if (!_dropoffLocations.contains(_selectedDropoff) && _dropoffLocations.isNotEmpty) {
        _selectedDropoff = _dropoffLocations.first;
      }
    });
  }

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _parsedItemCost => double.tryParse(_priceController.text.trim()) ?? 0.0;

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final double estimatedPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final qty = _quantityController.text.trim();
    final rawItem = _itemController.text.trim();
    final description = qty.isNotEmpty && qty != '1' ? '${qty}x $rawItem' : rawItem;
    final instructions = _notesController.text.trim();

    setState(() => _isSubmitting = true);

    String createdId;
    try {
      final inserted = await SupabaseService().createOrder(
        pickup: _selectedPickup,
        dropoff: _selectedDropoff,
        description: description,
        price: estimatedPrice,
        deliveryFee: _config.standardDeliveryFee,
        instructions: instructions,
        expiresIn: Duration(minutes: _config.requestExpirationMinutes),
      );
      createdId = inserted['id'].toString();
      addPabiliRequest(
        orderId: createdId,
        verificationCode: inserted['verification_code']?.toString(),
        customerId: inserted['customer_id']?.toString(),
        pickup: _selectedPickup,
        dropoff: _selectedDropoff,
        description: description,
        price: estimatedPrice,
        deliveryFee: _config.standardDeliveryFee,
        instructions: instructions,
        expiresIn: Duration(minutes: _config.requestExpirationMinutes),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: primaryMaroon,
            content: Text('Delivery request posted!'),
          ),
        );
      }
    } catch (e) {
      final fallback = addPabiliRequest(
        pickup: _selectedPickup,
        dropoff: _selectedDropoff,
        description: description,
        price: estimatedPrice,
        deliveryFee: _config.standardDeliveryFee,
        instructions: instructions,
        expiresIn: Duration(minutes: _config.requestExpirationMinutes),
      );
      createdId = fallback['id'].toString();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: primaryMaroon,
            content: Text('Saved in offline mode: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }

    if (mounted) {
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
    final totalEstimate = _parsedItemCost + _config.standardDeliveryFee;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'New Pabili Request',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: primaryMaroon,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup Location',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey('pickup-$_selectedPickup'),
                      initialValue: _selectedPickup,
                      items: _pickupLocations
                          .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPickup = val);
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Drop-off Location',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey('dropoff-$_selectedDropoff'),
                      initialValue: _selectedDropoff,
                      items: _dropoffLocations
                          .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDropoff = val);
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Items to Buy',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _itemController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'e.g., Pork Siomai w/ rice, Mountain Dew',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty
                                    ? 'Please enter item details'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Qty',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _quantityController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 14,
                                  ),
                                ),
                                validator: (val) {
                                  final q = int.tryParse(val?.trim() ?? '');
                                  return (q == null || q < 1) ? 'Min 1' : null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Estimated Item Budget (₱)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '85.00',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      validator: Validators.validateEstimatedBudget,
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Special Notes / Instructions',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Meet outside 3rd floor stairs',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Cost & Direct Payment Summary (SRS 3.1.3.4, 3.2.1)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF4F4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: primaryMaroon.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(child: Text('Estimated Item Cost', style: TextStyle(fontSize: 13))),
                              Text(
                                '₱${_parsedItemCost.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(child: Text('Standard Campus Delivery Fee',
                                  style: TextStyle(fontSize: 13))),
                              Text(
                                '₱${_config.standardDeliveryFee.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Estimated Total',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              Text(
                                '₱${totalEstimate.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryMaroon,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Payment: Direct cash or personal GCash to runner upon handover.',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Unclaimed requests expire automatically after ${_config.requestExpirationMinutes} minutes.',
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitOrder,
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
                                'Post Delivery Request',
                                style: TextStyle(color: Colors.white, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
