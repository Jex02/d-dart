import 'package:flutter/material.dart';
import 'models/delivery_order.dart';
import 'models/problem_report.dart';
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
  static const List<String> _flowSteps = [
    'pending',
    'claimed',
    'purchasing',
    'en_route',
    'arrived',
    'completed',
  ];

  final _otpInputController = TextEditingController();
  Map<String, dynamic> _fallbackOrder = {};
  bool _hasFallbackInMemory = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    final idx = mockDeliveryRequests.indexWhere(
      (req) => req['id'].toString() == widget.orderId,
    );
    if (idx != -1) {
      _fallbackOrder = Map<String, dynamic>.from(mockDeliveryRequests[idx]);
      _hasFallbackInMemory = true;
    } else {
      _fallbackOrder = {
        'id': widget.orderId,
        'status': 'pending',
        'description': 'Pabili delivery item',
        'pickup_location': 'Campus Canteen',
        'dropoff_location': 'Campus Drop-off',
        'estimated_price': 0.0,
        'delivery_fee': 20.0,
        'verification_code': '0000',
      };
    }
  }

  @override
  void dispose() {
    _otpInputController.dispose();
    super.dispose();
  }

  void _syncMockStatus(String status) {
    _fallbackOrder['status'] = status;
    final idx = mockDeliveryRequests.indexWhere(
      (r) => r['id'].toString() == widget.orderId,
    );
    if (idx != -1) {
      mockDeliveryRequests[idx]['status'] = status;
      if (status == 'completed') {
        mockDeliveryRequests[idx]['completed_at'] =
            DateTime.now().toUtc().toIso8601String();
      }
    }
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

    setState(() => _isBusy = true);
    try {
      await SupabaseService().updateOrderStatus(widget.orderId, nextStatus);
      setState(() => _syncMockStatus(nextStatus));
    } catch (e) {
      if (widget.orderId.startsWith('ORD-') || !SupabaseService().isAuthenticated) {
        setState(() => _syncMockStatus(nextStatus));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Could not update status: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _verifyOtp(String expectedOtp) async {
    final input = _otpInputController.text.trim();
    if (input.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Please enter the 4-digit handover code.'),
        ),
      );
      return;
    }

    setState(() => _isBusy = true);
    bool verified = false;
    try {
      verified = await SupabaseService().verifyAndCompleteOrder(widget.orderId, input);
    } catch (_) {
      if (widget.orderId.startsWith('ORD-') || !SupabaseService().isAuthenticated) {
        verified = (input == expectedOtp);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }

    if (verified) {
      setState(() => _syncMockStatus('completed'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Delivery verified and completed!'),
          ),
        );
        Navigator.pop(context, true);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Invalid 4-digit code. Handover blocked until verified.'),
        ),
      );
    }
  }

  Future<void> _handleCancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: const Text(
          'Only unclaimed pending requests can be cancelled. Are you sure you want to cancel this request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isBusy = true);
    final cancelled = await SupabaseService().cancelOrder(widget.orderId);
    if (mounted) {
      setState(() => _isBusy = false);
      if (cancelled) {
        setState(() => _fallbackOrder['status'] = 'cancelled');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery request cancelled.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Could not cancel — request may already be claimed or expired.'),
          ),
        );
      }
    }
  }

  Future<void> _openReportProblemDialog() async {
    String category = 'late_delivery';
    final descCtrl = TextEditingController();

    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Report a Delivery Problem'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Issue Category',
                  border: OutlineInputBorder(),
                ),
                items: ProblemReport.categoryLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => category = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText: 'Explain what happened so an admin can review it.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
    final description = descCtrl.text.trim();
    descCtrl.dispose();

    if (submit == true && description.isNotEmpty) {
      await SupabaseService().submitProblemReport(
        requestId: widget.orderId.startsWith('ORD-') ? null : widget.orderId,
        category: category,
        description: description,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Problem reported for Administrator review.')),
        );
      }
    }
  }

  String _formatStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Waiting for Runner';
      case 'claimed':
        return 'Runner Claimed';
      case 'purchasing':
        return 'Purchasing Items';
      case 'en_route':
        return 'En Route to Drop-off';
      case 'arrived':
        return 'Arrived at Drop-off';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMockOrder = widget.orderId.startsWith('ORD-');
    final isSignedInOnline = !isMockOrder && SupabaseService().isAuthenticated;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: isMockOrder
          ? Stream.value([_fallbackOrder])
          : SupabaseService().streamOrder(widget.orderId),
      builder: (context, snapshot) {
        if (isSignedInOnline &&
            !_hasFallbackInMemory &&
            !snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text('Loading Order...', style: TextStyle(color: Colors.white, fontSize: 18)),
              backgroundColor: primaryMaroon,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: const Center(child: CircularProgressIndicator(color: primaryMaroon)),
          );
        }

        Map<String, dynamic> raw = _fallbackOrder;
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          raw = snapshot.data!.first;
        }
        final order = DeliveryOrder.fromJson(raw);
        final effectiveStatus = order.effectiveStatus();
        final isCompleted = effectiveStatus == 'completed';
        final isTerminated =
            effectiveStatus == 'cancelled' || effectiveStatus == 'expired';
        final currentStepIndex = _flowSteps.indexOf(effectiveStatus);
        final isArrived = effectiveStatus == 'arrived';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              'Order ${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            backgroundColor: primaryMaroon,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                tooltip: 'Report a problem',
                icon: const Icon(Icons.report_problem_outlined),
                onPressed: _openReportProblemDialog,
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isTerminated
                              ? Colors.grey.shade200
                              : isCompleted
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : primaryMaroon.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isCompleted
                                  ? Icons.check_circle
                                  : isTerminated
                                      ? Icons.cancel_outlined
                                      : Icons.local_shipping_outlined,
                              color: isCompleted
                                  ? Colors.green
                                  : isTerminated
                                      ? Colors.black54
                                      : primaryMaroon,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _formatStatusLabel(effectiveStatus),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted
                                      ? Colors.green.shade800
                                      : isTerminated
                                          ? Colors.black87
                                          : primaryMaroon,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (!isTerminated) ...[
                        _DeliveryProgressStepper(
                          steps: _flowSteps,
                          currentIndex: currentStepIndex,
                          labelBuilder: _formatStatusLabel,
                        ),
                        const SizedBox(height: 18),
                      ],

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _detailRow('Pickup', order.pickupLocation),
                            const SizedBox(height: 6),
                            _detailRow('Drop-off', order.dropoffLocation),
                            const SizedBox(height: 6),
                            _detailRow('Items', order.description),
                            if (order.specialInstructions.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _detailRow('Notes', order.specialInstructions),
                            ],
                            const Divider(height: 18),
                            _detailRow(
                              'Estimated Food Cost',
                              '₱${order.estimatedPrice.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 4),
                            _detailRow(
                              'Delivery Fee',
                              '₱${order.deliveryFee.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 4),
                            _detailRow(
                              'Estimated Total',
                              '₱${order.totalAmount.toStringAsFixed(2)}',
                              bold: true,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Direct Payment: Cash or personal GCash to runner on handover.',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Customer 4-digit OTP box (SDD 6.3.6 / C.3: Revealed upon runner arrival)
                      if (!widget.isRunner && !isCompleted && !isTerminated) ...[
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
                              const Text(
                                'Handover Verification Code',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              if (isArrived) ...[
                                Text(
                                  order.verificationCode.isEmpty
                                      ? '----'
                                      : order.verificationCode,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 8,
                                    color: primaryMaroon,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Your runner has arrived! Share this 4-digit code upon receiving your items.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11),
                                ),
                              ] else ...[
                                const Icon(Icons.lock_outline, size: 28, color: primaryMaroon),
                                const SizedBox(height: 6),
                                const Text(
                                  'Your 4-digit code will appear here once the runner arrives at drop-off.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11.5, color: Colors.black87),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (!widget.isRunner && order.canCancelAt()) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: _isBusy ? null : _handleCancelOrder,
                            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                            label: const Text(
                              'Cancel Unclaimed Request',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],

                      if (widget.isRunner && !isCompleted && !isTerminated) ...[
                        if (!isArrived)
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _isBusy ? null : () => _advanceStatus(effectiveStatus),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryMaroon,
                                foregroundColor: Colors.white,
                              ),
                              child: _isBusy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      effectiveStatus == 'claimed'
                                          ? 'Mark as Purchasing Items'
                                          : effectiveStatus == 'purchasing'
                                              ? 'Mark as En Route'
                                              : 'Mark as Arrived',
                                    ),
                            ),
                          ),
                        if (isArrived) ...[
                          const Text(
                            'Enter Customer 4-Digit Code:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _otpInputController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: '1234',
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _isBusy
                                  ? null
                                  : () => _verifyOtp(order.verificationCode),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Confirm Handover & Complete'),
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          onPressed: _openReportProblemDialog,
                          icon: const Icon(Icons.flag_outlined, size: 16, color: Colors.black54),
                          label: const Text(
                            'Report a problem with this delivery',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ),
                      ),
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

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: bold ? primaryMaroon : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeliveryProgressStepper extends StatelessWidget {
  const _DeliveryProgressStepper({
    required this.steps,
    required this.currentIndex,
    required this.labelBuilder,
  });

  final List<String> steps;
  final int currentIndex;
  final String Function(String) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (i) {
        final done = currentIndex >= i;
        final isCurrent = currentIndex == i;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
                color: done ? const Color(0xFF7F0000) : Colors.grey.shade400,
              ),
              const SizedBox(width: 10),
              Text(
                labelBuilder(steps[i]),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: done ? Colors.black87 : Colors.black45,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
