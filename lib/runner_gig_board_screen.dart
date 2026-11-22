import 'dart:async';
import 'package:flutter/material.dart';
import 'models/campus_location.dart';
import 'models/delivery_order.dart';
import 'models/problem_report.dart';
import 'models/user_profile.dart';
import 'services/duty_lock_service.dart';
import 'services/supabase_service.dart';
import 'order_tracking_screen.dart';
import 'widgets/responsive_shell.dart';
import 'widgets/runner_order_items.dart';

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
  Timer? _refreshTimer;
  final Set<String> _locallyClaimedOrderIds = {};
  String _deliveriesFilter = 'all';
  late Stream<List<Map<String, dynamic>>> _availableOrdersStream;
  late Stream<List<Map<String, dynamic>>> _runnerAssignedOrdersStream;

  @override
  void initState() {
    super.initState();
    _availableOrdersStream = SupabaseService().streamAvailableOrders();
    _runnerAssignedOrdersStream = SupabaseService().streamRunnerAssignedOrders();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _refreshEligibility();
    });
    _refreshEligibility();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshEligibility() async {
    await SupabaseService().expireStaleOrders();
    await DutyLockService.syncFromSupabase();
    final profile = await SupabaseService().fetchUserProfileModel();
    if (mounted) {
      setState(() {
        _profile = profile;
        _availableOrdersStream = SupabaseService().streamAvailableOrders();
        _runnerAssignedOrdersStream = SupabaseService().streamRunnerAssignedOrders();
      });
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

    final currentUserId = SupabaseService().currentUser?.id;
    if (currentUserId != null && order.customerId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('You cannot claim your own delivery order.'),
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
          backgroundColor: result.status == ClaimOrderStatus.cannotClaimOwnOrder
              ? Colors.redAccent
              : Colors.orange.shade800,
          content: Text(result.message),
        ),
      );
      setState(() {});
      return;
    }

    // Immediately remove from available orders list (Task 4)
    _locallyClaimedOrderIds.add(order.id);
    _refreshEligibility();

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

  Future<void> _confirmAndReleaseOrder(DeliveryOrder order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release Claimed Order?'),
        content: const Text(
          'Did you claim this order by mistake? Releasing it will clear your claim and return it to the available gigs board so another runner can claim it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Release Order'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final released = await SupabaseService().releaseClaimedOrder(order.id);
    if (!mounted) return;
    if (released) {
      _locallyClaimedOrderIds.remove(order.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: primaryMaroon,
          content: Text('Order released! Returned to available gigs.'),
        ),
      );
      _refreshEligibility();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Could not release order. Please try again.'),
        ),
      );
    }
  }

  void _inspectGigDetails(DeliveryOrder order, bool canClaim) {
    final currentUserId = SupabaseService().currentUser?.id;
    final isOwnOrder =
        currentUserId != null && order.customerId == currentUserId;

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
            if (isOwnOrder) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.block, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You created this order. Customers cannot claim their own orders.',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            Text(
              'Ordered Items:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: DDartTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 4),
            RunnerOrderItemsList(description: order.description),
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
                onPressed: (canClaim && !isOwnOrder && !_isClaiming)
                    ? () {
                        Navigator.pop(ctx);
                        _handleClaimOrder(order);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryMaroon,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  isOwnOrder
                      ? 'Cannot Claim Own Order'
                      : canClaim
                          ? 'Claim This Gig'
                          : 'Unavailable (Duty Lock / Offline)',
                ),
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

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _runnerAssignedOrdersStream,
      builder: (context, assignedSnapshot) {
        final assignedOrders = (assignedSnapshot.data ?? []).map(DeliveryOrder.fromJson).toList();
        final activeOrders = assignedOrders.where((o) =>
          !const ['completed', 'cancelled', 'expired'].contains(o.effectiveStatus())
        ).toList();
        final hasActive = activeOrders.isNotEmpty;
        final activeCount = activeOrders.length;

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
              bottom: TabBar(
                indicatorColor: const Color(0xFFD4AF37),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  const Tab(text: 'Available Gigs'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('My Active Deliveries'),
                        if (hasActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 3,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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

                    // Active delivery banner with red dot notification
                    if (hasActive)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent,
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ACTIVE DELIVERY IN PROGRESS ($activeCount)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${activeOrders.first.pickupLocation} → ${activeOrders.first.dropoffLocation}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: DDartTheme.textPrimary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderTrackingScreen(
                                      orderId: activeOrders.first.id,
                                      isRunner: true,
                                    ),
                                  ),
                                ).then((_) => _refreshEligibility());
                              },
                              icon: const Icon(Icons.near_me, size: 13),
                              label: const Text('Track', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryMaroon,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildAvailableFeed(canClaimNow),
                          _buildMyDeliveriesFeed(assignedOrders),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailableFeed(bool canClaimNow) {
    final currentUserId = SupabaseService().currentUser?.id;

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
            .where((o) => !o.isExpiredAt() && !_locallyClaimedOrderIds.contains(o.id))
            .toList();

        if (orders.isEmpty) {
          return RefreshIndicator(
            color: primaryMaroon,
            onRefresh: _refreshEligibility,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    'No open deliveries right now.\nPull to refresh or check back shortly!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: primaryMaroon,
          onRefresh: _refreshEligibility,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final isOwnOrder =
                  currentUserId != null && order.customerId == currentUserId;

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
                            Row(
                              children: [
                                Text(
                                  order.id.length > 8 ? order.id.substring(0, 8) : order.id,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryMaroon,
                                  ),
                                ),
                                if (isOwnOrder) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.red.shade300, width: 0.8),
                                    ),
                                    child: Text(
                                      'YOUR ORDER',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
                        const SizedBox(height: 8),
                        Text(
                          'Ordered Items:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: DDartTheme.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        RunnerOrderItemsList(description: order.description),
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
                            onPressed: (!canClaimNow || isOwnOrder || _isClaiming)
                                ? null
                                : () => _handleClaimOrder(order),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryMaroon,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              isOwnOrder
                                  ? 'Cannot Claim Own Order'
                                  : 'Claim This Gig',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, BuildContext context) {
    final isSelected = _deliveriesFilter == value;
    final isDark = DDartTheme.isDark(context);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: isSelected,
      selectedColor: primaryMaroon,
      backgroundColor: DDartTheme.cardSubtle(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (_) => setState(() => _deliveriesFilter = value),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: DDartTheme.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderCard(DeliveryOrder order, bool isDark) {
    final status = order.effectiveStatus();
    final canRelease = status == 'claimed';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: DDartTheme.border(context)),
      ),
      color: DDartTheme.card(context),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: primaryMaroon,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Text(
                'Pickup: ${order.pickupLocation}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
              Text(
                'Drop-off: ${order.dropoffLocation}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Ordered Items:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: DDartTheme.textSecondary(context),
                ),
              ),
              const SizedBox(height: 4),
              RunnerOrderItemsList(description: order.description),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Earnings: ₱${order.deliveryFee.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    'Tap to Track →',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: DDartTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
              if (canRelease) ...[
                const Divider(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _confirmAndReleaseOrder(order),
                    icon: const Icon(Icons.undo, size: 15, color: Colors.orange),
                    label: const Text(
                      'Release Claim / Mistaken Claim',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPastOrderCard(DeliveryOrder order, bool isDark) {
    final status = order.effectiveStatus();
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCompleted
              ? (isDark ? Colors.green.shade800.withValues(alpha: 0.6) : Colors.green.shade200)
              : DDartTheme.border(context),
        ),
      ),
      color: DDartTheme.card(context),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: DDartTheme.textPrimary(context),
                    ),
                  ),
                  // TASK 6: In runner-side Past Orders section, Completed status displayed using a green-colored badge/indicator
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1B5E20).withValues(alpha: 0.35)
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.green.shade600 : Colors.green.shade400,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: isDark ? Colors.greenAccent.shade200 : Colors.green.shade700,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'COMPLETED',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.greenAccent.shade200 : Colors.green.shade800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isCancelled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.red.withValues(alpha: 0.16)
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? Colors.red.shade700 : Colors.red.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cancel,
                            size: 13,
                            color: isDark ? Colors.redAccent.shade100 : Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'CANCELLED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.redAccent.shade100 : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.withValues(alpha: 0.2)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 13,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const Divider(height: 16),
              Text(
                'Pickup: ${order.pickupLocation}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
              Text(
                'Drop-off: ${order.dropoffLocation}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              // TASK 7: Display runner order items one per line
              Text(
                'Ordered Items:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: DDartTheme.textSecondary(context),
                ),
              ),
              const SizedBox(height: 4),
              RunnerOrderItemsList(description: order.description),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Earned: ₱${order.deliveryFee.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.green.shade700 : DDartTheme.textSecondary(context),
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    'View History →',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: DDartTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyDeliveriesFeed([List<DeliveryOrder>? preloadedOrders]) {
    Widget buildList(List<DeliveryOrder> orders) {
      if (orders.isEmpty) {
        return RefreshIndicator(
          color: primaryMaroon,
          onRefresh: _refreshEligibility,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              Center(
                child: Text(
                  'You have no claimed deliveries yet.\nPull to refresh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }

      final activeOrders = orders.where((o) =>
        !const ['completed', 'cancelled', 'expired'].contains(o.effectiveStatus())
      ).toList();

      final pastOrders = orders.where((o) =>
        const ['completed', 'cancelled', 'expired'].contains(o.effectiveStatus())
      ).toList();

      final isDark = DDartTheme.isDark(context);

      return RefreshIndicator(
        color: primaryMaroon,
        onRefresh: _refreshEligibility,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Filter toggle chips: All, Active Orders, Past Orders
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All (${orders.length})', 'all', context),
                  const SizedBox(width: 8),
                  _buildFilterChip('Active Orders (${activeOrders.length})', 'active', context),
                  const SizedBox(width: 8),
                  _buildFilterChip('Past Orders (${pastOrders.length})', 'past', context),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // When "All" is selected
            if (_deliveriesFilter == 'all') ...[
              if (activeOrders.isNotEmpty) ...[
                _buildSectionHeader(
                  'Active Orders (${activeOrders.length})',
                  Icons.delivery_dining,
                  primaryMaroon,
                ),
                ...activeOrders.map((o) => _buildActiveOrderCard(o, isDark)),
              ],
              if (pastOrders.isNotEmpty) ...[
                _buildSectionHeader(
                  'Past Orders (${pastOrders.length})',
                  Icons.history,
                  Colors.green.shade800,
                ),
                ...pastOrders.map((o) => _buildPastOrderCard(o, isDark)),
              ],
            ],

            // When "Active Orders" filter is selected
            if (_deliveriesFilter == 'active') ...[
              _buildSectionHeader(
                'Active Orders (${activeOrders.length})',
                Icons.delivery_dining,
                primaryMaroon,
              ),
              if (activeOrders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text(
                    'No active deliveries in progress.',
                    style: TextStyle(color: DDartTheme.textMuted(context), fontSize: 13),
                  ),
                )
              else
                ...activeOrders.map((o) => _buildActiveOrderCard(o, isDark)),
            ],

            // When "Past Orders" filter is selected
            if (_deliveriesFilter == 'past') ...[
              _buildSectionHeader(
                'Past Orders (${pastOrders.length})',
                Icons.history,
                Colors.green.shade800,
              ),
              if (pastOrders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text(
                    'No past deliveries found.',
                    style: TextStyle(color: DDartTheme.textMuted(context), fontSize: 13),
                  ),
                )
              else
                ...pastOrders.map((o) => _buildPastOrderCard(o, isDark)),
            ],
          ],
        ),
      );
    }

    if (preloadedOrders != null) {
      return buildList(preloadedOrders);
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _runnerAssignedOrdersStream,
      builder: (context, snapshot) {
        final orders = (snapshot.data ?? []).map(DeliveryOrder.fromJson).toList();
        return buildList(orders);
      },
    );
  }
}
