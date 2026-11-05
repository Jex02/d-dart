import 'package:flutter/material.dart';
import 'mock_data.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final bool isRunner;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.isRunner = false,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  static const Color primaryMaroon = Color(0xFF7F0000);
  final _otpInputController = TextEditingController();

  Map<String, dynamic> get _order =>
      mockDeliveryRequests.firstWhere((req) => req['id'] == widget.orderId);

  void _advanceStatus() {
    setState(() {
      final current = _order['status'];
      if (current == 'claimed') {
        _order['status'] = 'purchasing';
      } else if (current == 'purchasing') {
        _order['status'] = 'en_route';
      } else if (current == 'en_route') {
        _order['status'] = 'arrived';
      }
    });
  }

  void _verifyOtp() {
    if (_otpInputController.text.trim() == _order['verification_code']) {
      setState(() {
        _order['status'] = 'completed';
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Delivery verified and completed!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Invalid 4-digit code. Please verify with customer.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _order['status'];
    final isCompleted = status == 'completed';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Order Status: ${_order['id']}', style: const TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: primaryMaroon,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryMaroon.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'STATUS: ${status.toString().toUpperCase()}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryMaroon),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Items: ${_order['description']}', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text('Drop-off: ${_order['dropoff_location']}', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 20),

                if (!widget.isRunner && !isCompleted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5EBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryMaroon),
                    ),
                    child: Column(
                      children: [
                        const Text('Handover Verification Code', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          _order['verification_code'],
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: primaryMaroon),
                        ),
                        const SizedBox(height: 4),
                        const Text('Give this 4-digit code to the runner when receiving your meal.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],

                if (widget.isRunner && !isCompleted) ...[
                  if (status != 'arrived')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _advanceStatus,
                        style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon),
                        child: Text(
                          status == 'claimed'
                              ? 'Mark as Purchasing Food'
                              : status == 'purchasing'
                                  ? 'Mark as En Route'
                                  : 'Mark as Arrived',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  if (status == 'arrived') ...[
                    const Text('Enter Customer 4-Digit Code:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _otpInputController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '1234'),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _verifyOtp,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('Confirm Handover & Complete', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
