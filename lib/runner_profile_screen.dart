import 'package:flutter/material.dart';
import 'models/runner_performance.dart';
import 'models/runner_review.dart';
import 'services/supabase_service.dart';
import 'widgets/responsive_shell.dart';

class RunnerProfileScreen extends StatefulWidget {
  final String? runnerId;
  final String? runnerName;

  const RunnerProfileScreen({
    super.key,
    this.runnerId,
    this.runnerName,
  });

  @override
  State<RunnerProfileScreen> createState() => _RunnerProfileScreenState();
}

class _RunnerProfileScreenState extends State<RunnerProfileScreen> {
  static const Color primaryMaroon = Color(0xFF7F0000);
  static const Color gold = Color(0xFFD4AF37);

  bool _isLoading = true;
  RunnerPerformance? _performance;
  List<RunnerReview> _reviews = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUserId = SupabaseService().currentUser?.id;
      final targetRunnerId = widget.runnerId ?? currentUserId ?? 'runner-demo';

      final userProfile = targetRunnerId == currentUserId
          ? await SupabaseService().fetchUserProfileModel()
          : null;

      final perf = await SupabaseService().fetchRunnerPerformance(
        targetRunnerId,
        runnerName: widget.runnerName ?? userProfile?.fullName,
        studentId: userProfile?.studentId,
      );

      final reviews = await SupabaseService().fetchRunnerReviews(targetRunnerId);

      if (mounted) {
        setState(() {
          _performance = perf;
          _reviews = reviews;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load runner profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = DDartTheme.isDark(context);
    final isSelf = widget.runnerId == null ||
        widget.runnerId == SupabaseService().currentUser?.id;

    return Scaffold(
      backgroundColor: DDartTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          isSelf ? 'My Runner Profile' : (_performance?.runnerName ?? 'Runner Profile'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryMaroon,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [
          ThemeToggleButton(iconColor: Colors.white, iconSize: 21),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryMaroon),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadProfileData,
                          style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon),
                          child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: primaryMaroon,
                  onRefresh: _loadProfileData,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        children: [
                          _buildProfileHeaderCard(isDark),
                          const SizedBox(height: 16),
                          _buildStatsOverview(isDark),
                          const SizedBox(height: 24),
                          _buildReviewsSection(isDark),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildProfileHeaderCard(bool isDark) {
    final perf = _performance;
    final name = perf?.runnerName ?? 'Student Runner';
    final studentId = perf?.studentId ?? '';
    final photoUrl = perf?.photoUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DDartTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DDartTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryMaroon,
              border: Border.all(color: gold, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.directions_run_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    )
                  : const Icon(
                      Icons.directions_run_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: DDartTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryMaroon.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryMaroon.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, size: 14, color: primaryMaroon),
                    const SizedBox(width: 4),
                    Text(
                      studentId.isNotEmpty ? 'Runner ID: $studentId' : 'Verified Student Runner',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryMaroon,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Prominent Rating Display
          if (perf != null && perf.hasRatings) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: gold.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: gold, size: 24),
                  const SizedBox(width: 6),
                  Text(
                    '${perf.ratingDisplay} ★',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFFFD54F) : const Color(0xFFB78103),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${perf.totalReviews} review${perf.totalReviews > 1 ? "s" : ""})',
                    style: TextStyle(
                      fontSize: 13,
                      color: DDartTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: DDartTheme.cardSubtle(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: DDartTheme.border(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_outline_rounded, color: DDartTheme.textMuted(context), size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'No Ratings Yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DDartTheme.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsOverview(bool isDark) {
    final perf = _performance;
    final ratingText = perf != null && perf.hasRatings ? '${perf.ratingDisplay} ★' : 'No Ratings';
    final completedCount = perf?.completedDeliveries ?? 0;
    final reviewsCount = perf?.totalReviews ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Overall Rating',
            value: ratingText,
            icon: Icons.star_rate_rounded,
            iconColor: gold,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: 'Completed Deliveries',
            value: '$completedCount',
            icon: Icons.local_shipping_rounded,
            iconColor: Colors.green,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: 'Customer Reviews',
            value: '$reviewsCount',
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: primaryMaroon,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: DDartTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DDartTheme.border(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: DDartTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 10.5,
              color: DDartTheme.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Customer Reviews (${_reviews.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: DDartTheme.textPrimary(context),
              ),
            ),
            if (_performance?.hasRatings == true)
              Text(
                'Average: ${_performance!.ratingDisplay} / 5.0',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DDartTheme.accentText(context),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: DDartTheme.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DDartTheme.border(context)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 44,
                  color: DDartTheme.textMuted(context),
                ),
                const SizedBox(height: 12),
                Text(
                  'No reviews yet.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DDartTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete deliveries to earn customer feedback!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: DDartTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          )
        else
          ..._reviews.map((rev) => _buildReviewCard(rev, isDark)),
      ],
    );
  }

  Widget _buildReviewCard(RunnerReview rev, bool isDark) {
    final orderRef = rev.orderId.isNotEmpty
        ? (rev.orderId.length > 8 ? rev.orderId.substring(0, 8) : rev.orderId)
        : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DDartTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DDartTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: primaryMaroon.withValues(alpha: 0.1),
                    child: Text(
                      (rev.customerName?.isNotEmpty == true ? rev.customerName![0] : 'C').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryMaroon,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rev.customerName ?? 'Verified Customer',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: DDartTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
              Text(
                rev.formattedDate,
                style: TextStyle(
                  fontSize: 11,
                  color: DDartTheme.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Row(
                children: List.generate(5, (index) {
                  final filled = index < rev.rating;
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? gold : Colors.grey.shade400,
                    size: 18,
                  );
                }),
              ),
              const SizedBox(width: 8),
              Text(
                '${rev.rating}.0',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFFFD54F) : const Color(0xFFB78103),
                ),
              ),
              const Spacer(),
              if (orderRef != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: DDartTheme.cardSubtle(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Order #$orderRef',
                    style: TextStyle(
                      fontSize: 10,
                      color: DDartTheme.textSecondary(context),
                    ),
                  ),
                ),
            ],
          ),
          if (rev.reviewText != null && rev.reviewText!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"${rev.reviewText!.trim()}"',
              style: TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: DDartTheme.textPrimary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
