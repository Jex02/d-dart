import 'package:flutter/material.dart';
import 'mock_data.dart';
import 'order_tracking_screen.dart';

class RunnerGigBoardScreen extends StatefulWidget {
  const RunnerGigBoardScreen({super.key});

  @override
  State<RunnerGigBoardScreen> createState() => _RunnerGigBoardScreenState();
}

class _RunnerGigBoardScreenState extends State<RunnerGigBoardScreen> {
  static const Color primaryMaroon = Color(0xFF7F0000);

  @override
  Widget build(BuildContext context) {
    final pendingOrders = mockDeliveryRequests
        .where((req) => req['status'] == 'pending')
        .toList();

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
          child: pendingOrders.isEmpty
              ? const Center(
                  child: Text(
                    'No open deliveries right now.\nCheck back shortly!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pendingOrders.length,
                  itemBuilder: (context, index) {
                    final order = pendingOrders[index];
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
                                Text(order['id'], style: const TextStyle(fontWeight: FontWeight.bold, color: primaryMaroon)),
                                Text('Earn ₱${order['delivery_fee'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                            const Divider(height: 18),
                            Text('Pickup: ${order['pickup_location']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('Drop-off: ${order['dropoff_location']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text('Items: ${order['description']}', style: const TextStyle(color: Colors.black87)),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    order['status'] = 'claimed';
                                  });
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OrderTrackingScreen(
                                        orderId: order['id'],
                                        isRunner: true,
                                      ),
                                    ),
                                  ).then((_) => setState(() {}));
                                },
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
                ),
        ),
      ),
    );
  }
}
