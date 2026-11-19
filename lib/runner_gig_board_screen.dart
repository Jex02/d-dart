import 'package:flutter/material.dart';
import 'models/campus_location.dart';
import 'models/delivery_order.dart';
import 'models/problem_report.dart';
import 'models/user_profile.dart';
import 'services/duty_lock_service.dart';
import 'services/supabase_service.dart';
import 'order_tracking_screen.dart';
import 'widgets/responsive_shell.dart';

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
  late Stream<List<Map<String, dynamic>>> _availableOrdersStream;
  late Stream<List<Map<String, dynamic>>> _runnerAssignedOrdersStream;

  @override
  void initState() {
    super.initState();
    _availableOrdersStream = SupabaseService().streamAvailableOrders();
    _runnerAssignedOrdersStream = SupabaseService().streamRunnerAssignedOrders();
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

  Future<void> _openRunnerReportDialog() async {
    String category = 'unresponsive_user';
    final descCtrl = TextEditingController();

    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Runner Support & Issue Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Issue Category',
                  border: OutlineInputBorder(),
                ),
                items: ProblemReport.runnerCategories
                    .map((key) => DropdownMenuItem(
                          value: key,
                          child: Text(ProblemReport.categoryLabels[key] ?? key),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => category = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Describe the issue in detail',
                  hintText: 'Provide details so the Super Admin can review and resolve it...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
    final text = descCtrl.text.trim();
    descCtrl.dispose();
    if (submit == true && text.isNotEmpty) {
      try {
        await SupabaseService().submitProblemReport(
          category: category,
          description: text,
          reporterRole: 'runner',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Problem report submitted to Super Administrators.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Could not submit report: $e'),
            ),
          );
        }
      }
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
        setState(() {});
      }
      return;
    }

    if (!mounted) return;
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
            Builder(
              builder: (context) {
                final dist = CampusLocation.getDistanceMeters(
                  order.pickupLocation,
                  order.dropoffLocation,
                );
                if (dist == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.straighten, size: 14, color: primaryMaroon),
                      const SizedBox(width: 4),
                      Text(
                        'Distance: ${CampusLocation.formatDistance(dist)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
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

    final isDark = DDartTheme.isDark(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: DDartTheme.surface(context),
        appBar: AppBar(
          title: const Text(
            'Runner Gig Board',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          backgroundColor: primaryMaroon,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            const ThemeToggleButton(iconColor: Colors.white, iconSize: 21),
            IconButton(
              tooltip: 'Report a Problem / Support',
              icon: const Icon(Icons.report_problem_outlined),
              onPressed: _openRunnerReportDialog,
            ),
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
                        ? (isDark ? Colors.red.withValues(alpha: 0.16) : Colors.red.shade50)
                        : _isOnline
                            ? (isDark ? Colors.green.withValues(alpha: 0.16) : Colors.green.shade50)
                            : DDartTheme.cardSubtle(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLocked
                          ? Colors.red.shade300
                          : _isOnline
                              ? Colors.green.shade300
                              : DDartTheme.border(context),
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
                                : DDartTheme.textSecondary(context),
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: DDartTheme.textPrimary(context),
                              ),
                            ),
                            Text(
                              isLocked
                                  ? (dutyStatus['reason']?.toString() ?? '')
                                  : 'Completed today: $completed / $limit deliveries',
                              style: TextStyle(
                                fontSize: 11,
                                color: DDartTheme.textSecondary(context),
                              ),
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
      stream: _availableOrdersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: primaryMaroon),
          );
        }

        final rawOrders = snapshot.data ?? [];

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
                      Builder(
                        builder: (context) {
                          final dist = CampusLocation.getDistanceMeters(
                            order.pickupLocation,
                            order.dropoffLocation,
                          );
                          if (dist == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Distance: ${CampusLocation.formatDistance(dist)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text('Items: ${order.description}'),
                      const SizedBox(height: 4),
                      Text(
                        'Est. Item Budget: ₱${order.estimatedPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: DDartTheme.accentText(context),
                          fontSize: 12.5,
                        ),
                      ),
                      if (order.specialInstructions.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Note: ${order.specialInstructions}',
                          style: TextStyle(
                            color: DDartTheme.textSecondary(context),
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
      stream: _runnerAssignedOrdersStream,
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
