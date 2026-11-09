import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
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

  Map<String, dynamic> _fallbackOrder = {};

  @override
  void initState() {
    super.initState();
    try {
      _fallbackOrder = mockDeliveryRequests.firstWhere(
        (req) => req['id'].toString() == widget.orderId,
        orElse: () => {
          'id': widget.orderId,
          'status': 'pending',
          'description': 'Pabili delivery item',
          'dropoff_location': 'Campus dropoff',
          'verification_code': '0000',
        },
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _otpInputController.dispose();
    super.dispose();
  }

  Future<void> _advanceStatus(String currentStatus) async {
    String nextStatus = 'claimed';
    if (currentStatus == 'claimed') {
      nextStatus = 'purchasing';
    } else if (currentStatus == 'purchasing') {
      nextStatus = 'en_route';
    } else if (currentStatus == 'en_route') {
      nextStatus = 'arrived';
    }

    try {
      await SupabaseService().updateOrderStatus(widget.orderId, nextStatus);
    } catch (_) {}

    setState(() {
      _fallbackOrder['status'] = nextStatus;
    });
  }

  Future<void> _verifyOtp(String expectedOtp) async {
    final input = _otpInputController.text.trim();

    bool verified = false;
    try {
      verified = await SupabaseService().verifyAndCompleteOrder(widget.orderId, input);
    } catch (_) {
      verified = (input == expectedOtp);
    }

    if (!verified && input == expectedOtp) {
      verified = true;
    }

    if (verified) {
      setState(() {
        _fallbackOrder['status'] = 'completed';
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Delivery verified and completed!'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Invalid 4-digit code. Please verify with customer.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService().streamOrder(widget.orderId),
      builder: (context, snapshot) {
        Map<String, dynamic> order = _fallbackOrder;

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          order = snapshot.data!.first;
        }

        final status = (order['status'] ?? 'pending').toString();
        final isCompleted = status == 'completed';
        final verificationCode = (order['verification_code'] ?? '----').toString();

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text('Order Status: ${order['id'] ?? widget.orderId}', style: const TextStyle(color: Colors.white, fontSize: 18)),
            backgroundColor: primaryMaroon,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
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
                        'STATUS: ${status.toUpperCase()}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryMaroon),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Items: ${order['description'] ?? ''}', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Drop-off: ${order['dropoff_location'] ?? ''}', style: const TextStyle(fontSize: 14)),
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
                              verificationCode,
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
                            onPressed: () => _advanceStatus(status),
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
                            onPressed: () => _verifyOtp(verificationCode),
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
        ),
      );
      },
    );
  }
}
