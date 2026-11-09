import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'mock_data.dart';
import 'order_tracking_screen.dart';

class RunnerGigBoardScreen extends StatefulWidget {
  const RunnerGigBoardScreen({super.key});

  @override
  State<RunnerGigBoardScreen> createState() => _RunnerGigBoardScreenState();
}

class _RunnerGigBoardScreenState extends State<RunnerGigBoardScreen> {
  static const Color primaryMaroon = Color(0xFF7F0000);

  Future<void> _handleClaimOrder(Map<String, dynamic> order) async {
    final orderId = order['id'].toString();

    try {
      await SupabaseService().claimOrder(orderId);
    } catch (_) {
      // Local fallback
      order['status'] = 'claimed';
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTrackingScreen(
            orderId: orderId,
            isRunner: true,
          ),
        ),
      ).then((_) => setState(() {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Available Gigs (Runner Mode)', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: primaryMaroon,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService().streamAvailableOrders(),
            builder: (context, snapshot) {
              List<Map<String, dynamic>> orders = [];

              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                orders = snapshot.data!;
              } else {
                // Fallback to local mock data
                orders = mockDeliveryRequests
                    .where((req) => req['status'] == 'pending')
                    .toList();
              }

              if (orders.isEmpty) {
                return const Center(
                  child: Text(
                    'No open deliveries right now.\nCheck back shortly!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final fee = (order['delivery_fee'] is num)
                      ? (order['delivery_fee'] as num).toDouble()
                      : 20.0;

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                order['id'].toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: primaryMaroon),
                              ),
                              Text(
                                'Earn ₱${fee.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Text('Pickup: ${order['pickup_location']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Drop-off: ${order['dropoff_location']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('Items: ${order['description']}', style: const TextStyle(color: Colors.black87)),
                          if (order['special_instructions'] != null && order['special_instructions'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Note: ${order['special_instructions']}',
                              style: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic, fontSize: 12),
                            ),
                          ],
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _handleClaimOrder(order),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryMaroon,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Claim This Gig', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
