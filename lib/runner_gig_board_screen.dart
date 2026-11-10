import 'package:flutter/material.dart';
import 'models/delivery_order.dart';
import 'services/duty_lock_service.dart';
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
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    SupabaseService().expireStaleOrders();
  }

  Future<void> _handleClaimOrder(DeliveryOrder order) async {
    if (_isClaiming) return;

    // Re-verify runner eligibility & active class lock right before claiming (WBS 4.3)
    final profile = await SupabaseService().fetchUserProfileModel();
    final dutyStatus = DutyLockService.checkDutyStatus(profile: profile);
    if (dutyStatus['isLocked'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(dutyStatus['reason']?.toString() ?? 'Runner access locked.'),
          ),
        );
      }
      return;
    }

    if (order.isExpiredAt()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('This delivery request has expired.'),
          ),
        );
      }
      setState(() {});
      return;
    }

    setState(() => _isClaiming = true);
    final result = await SupabaseService().claimOrder(order.id);
    if (!mounted) return;
    setState(() => _isClaiming = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.shade800,
          content: Text(result.message),
        ),
      );
      setState(() {});
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(
          orderId: order.id,
          isRunner: true,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Runner Gig Board',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          backgroundColor: primaryMaroon,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Color(0xFFD4AF37),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Available Gigs'),
              Tab(text: 'My Active Deliveries'),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: TabBarView(
              children: [
                _buildAvailableFeed(),
                _buildMyDeliveriesFeed(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableFeed() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService().streamAvailableOrders(),
      builder: (context, snapshot) {
        List<Map<String, dynamic>> rawOrders;
        if (snapshot.hasData) {
          rawOrders = snapshot.data!;
        } else {
          expireStaleMockOrders();
          rawOrders = mockDeliveryRequests
              .where((req) => req['status'] == 'pending')
              .toList();
        }

        final orders = rawOrders
            .map(DeliveryOrder.fromJson)
            .where((o) => !o.isExpiredAt())
            .toList();

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
                          order.id.length > 8 ? order.id.substring(0, 8) : order.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryMaroon,
                          ),
                        ),
                        Text(
                          'Earn ₱${order.deliveryFee.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      'Pickup: ${order.pickupLocation}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Drop-off: ${order.dropoffLocation}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text('Items: ${order.description}'),
                    const SizedBox(height: 4),
                    Text(
                      'Est. Item Budget: ₱${order.estimatedPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: primaryMaroon,
                        fontSize: 12.5,
                      ),
                    ),
                    if (order.specialInstructions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Note: ${order.specialInstructions}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isClaiming ? null : () => _handleClaimOrder(order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryMaroon,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Claim This Gig',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyDeliveriesFeed() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService().streamRunnerAssignedOrders(),
      builder: (context, snapshot) {
        final orders = (snapshot.data ?? []).map(DeliveryOrder.fromJson).toList();
        if (orders.isEmpty) {
          return const Center(
            child: Text(
              'You have no claimed deliveries yet.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(
                  order.description,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${order.pickupLocation} → ${order.dropoffLocation}\nStatus: ${order.status.toUpperCase()}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right, color: primaryMaroon),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderTrackingScreen(
                        orderId: order.id,
                        isRunner: true,
                      ),
                    ),
                  ).then((_) => setState(() {}));
                },
              ),
            );
          },
        );
      },
    );
  }
}
