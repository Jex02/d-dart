import 'package:flutter/material.dart';
import 'mock_data.dart';

class PabiliRequestScreen extends StatefulWidget {
  const PabiliRequestScreen({super.key});

  @override
  State<PabiliRequestScreen> createState() => _PabiliRequestScreenState();
}

class _PabiliRequestScreenState extends State<PabiliRequestScreen> {
  static const Color primaryMaroon = Color(0xFF7F0000);

  final _formKey = GlobalKey<FormState>();
  final _itemController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedPickup = 'Main Canteen';
  String _selectedDropoff = 'ALLIED Building';

  final List<String> _pickupLocations = [
    'Main Canteen',
    'College Canteen',
    'Elementary Canteen',
    'Campus Kiosks',
  ];

  final List<String> _dropoffLocations = [
    'ALLIED Building',
    'GLE Building',
    'Main Building',
    'University Library',
    'Department Offices',
  ];

  void _submitOrder() {
    if (_formKey.currentState!.validate()) {
      final double estimatedPrice = double.tryParse(_priceController.text) ?? 50.0;

      addPabiliRequest(
        pickup: _selectedPickup,
        dropoff: _selectedDropoff,
        description: _itemController.text,
        price: estimatedPrice,
        instructions: _notesController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: primaryMaroon,
          content: Text('Delivery request posted successfully!'),
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New Pabili Request', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: primaryMaroon,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pickup Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedPickup,
                    items: _pickupLocations
                        .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedPickup = val!),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Drop-off Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedDropoff,
                    items: _dropoffLocations
                        .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedDropoff = val!),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Items to Buy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _itemController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g., 2 orders Pork Siomai w/ rice, 1 Mountain Dew',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Please enter item details' : null,
                  ),
                  const SizedBox(height: 16),

                  const Text('Estimated Food Cost (₱)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '85.00',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid amount' : null,
                  ),
                  const SizedBox(height: 16),

                  const Text('Special Notes / Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Meet outside 3rd floor stairs',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBF4F4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primaryMaroon.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Campus Delivery Fee', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('₱20.00', style: TextStyle(fontWeight: FontWeight.bold, color: primaryMaroon, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryMaroon,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Post Delivery Request', style: TextStyle(color: Colors.white, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
