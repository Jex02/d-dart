import 'package:flutter/material.dart';
import 'models/delivery_order.dart';
import 'models/user_profile.dart';
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
  bool _isOnline = true;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _refreshEligibility();
  }

  Future<void> _refreshEligibility() async {
    await SupabaseService().expireStaleOrders();
    await DutyLockService.syncFromSupabase();
    final profile = await SupabaseService().fetchUserProfileModel();
    if (mounted) {
      setState(() => _profile = profile);
    }
  }

  Future<void> _handleClaimOrder(DeliveryOrder order) async {
    if (_isClaiming) return;
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Switch "Go Online" on to claim delivery requests.'),
        ),
      );
      return;
    }

    await DutyLockService.syncFromSupabase();
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
    ).then((_) => _refreshEligibility());
  }

  void _inspectGigDetails(DeliveryOrder order, bool canClaim) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Details',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: primaryMaroon),
            ),
            const Divider(height: 18),
            Text('Pickup: ${order.pickupLocation}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Drop-off: ${order.dropoffLocation}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Items: ${order.description}'),
            const SizedBox(height: 6),
            Text('Est. Item Budget: ₱${order.estimatedPrice.toStringAsFixed(2)}'),
            Text('Delivery Earnings: ₱${order.deliveryFee.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            if (order.specialInstructions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Instructions: ${order.specialInstructions}',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: canClaim && !_isClaiming
                    ? () {
                        Navigator.pop(ctx);
                        _handleClaimOrder(order);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryMaroon,
                  foregroundColor: Colors.white,
                ),
                child: Text(canClaim ? 'Claim This Gig' : 'Unavailable (Duty Lock / Offline)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dutyStatus = DutyLockService.checkDutyStatus(profile: _profile);
    final isLocked = dutyStatus['isLocked'] == true;
    final completed = DutyLockService.completedDeliveriesToday;
    final limit = DutyLockService.activeConfig.dailyDeliveryLimit;
    final canClaimNow = _isOnline && !isLocked;

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
          actions: [
            IconButton(
              tooltip: 'Refresh eligibility',
              icon: const Icon(Icons.refresh),
              onPressed: _refreshEligibility,
            ),
          ],
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
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                // Duty Lock & Go Online/Offline Status Toggle (SDD 6.3.7)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? Colors.red.shade50
                        : _isOnline
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLocked
                          ? Colors.red.shade300
                          : _isOnline
                              ? Colors.green.shade300
                              : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isLocked
                            ? Icons.lock_clock
                            : _isOnline
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                        color: isLocked
                            ? Colors.red.shade700
                            : _isOnline
                                ? Colors.green.shade700
                                : Colors.black54,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLocked
                                  ? 'Duty Lock Active'
                                  : _isOnline
                                      ? 'Online · Ready for Gigs'
                                      : 'Offline',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              isLocked
                                  ? (dutyStatus['reason']?.toString() ?? '')
                                  : 'Completed today: $completed / $limit deliveries',
                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: !isLocked && _isOnline,
                        activeThumbColor: Colors.green,
                        onChanged: isLocked
                            ? null
                            : (val) => setState(() => _isOnline = val),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    children: [
                      _buildAvailableFeed(canClaimNow),
                      _buildMyDeliveriesFeed(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableFeed(bool canClaimNow) {
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
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _inspectGigDetails(order, canClaimNow),
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
                          onPressed:
                              (!canClaimNow || _isClaiming) ? null : () => _handleClaimOrder(order),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryMaroon,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Claim This Gig'),
                        ),
                      ),
                    ],
                  ),
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
                  '${order.pickupLocation} → ${order.dropoffLocation}\nStatus: ${order.effectiveStatus().toUpperCase()}',
                ),
                isThreeLine: true,
                trailing: Chip(
                  label: Text(
                    order.effectiveStatus() == 'completed' ? 'DONE' : 'ACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: order.effectiveStatus() == 'completed'
                          ? Colors.green.shade800
                          : primaryMaroon,
                    ),
                  ),
                  backgroundColor: order.effectiveStatus() == 'completed'
                      ? Colors.green.shade50
                      : primaryMaroon.withValues(alpha: 0.1),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderTrackingScreen(
                        orderId: order.id,
                        isRunner: true,
                      ),
                    ),
                  ).then((_) => _refreshEligibility());
                },
              ),
            );
          },
        );
      },
    );
  }
}
