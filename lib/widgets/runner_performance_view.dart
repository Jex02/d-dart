import 'package:flutter/material.dart';
import '../models/runner_performance.dart';
import '../runner_profile_screen.dart';
import '../services/supabase_service.dart';
import 'responsive_shell.dart';

class RunnerPerformanceView extends StatefulWidget {
  const RunnerPerformanceView({super.key});

  @override
  State<RunnerPerformanceView> createState() => _RunnerPerformanceViewState();
}

class _RunnerPerformanceViewState extends State<RunnerPerformanceView> {
  static const Color primaryMaroon = Color(0xFF7F0000);
  static const Color gold = Color(0xFFD4AF37);

  bool _isLoading = true;
  List<RunnerPerformance> _runners = [];
  String? _error;
  String _sortBy = 'highest_rating'; // 'highest_rating', 'lowest_rating', 'most_deliveries', 'most_reviews'
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await SupabaseService().fetchAllRunnerPerformances();
      if (mounted) {
        setState(() {
          _runners = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load runner performance data: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<RunnerPerformance> _getSortedAndFilteredRunners() {
    final query = _searchCtrl.text.trim().toLowerCase();
    var filtered = _runners.where((r) {
      if (query.isEmpty) return true;
      return r.runnerName.toLowerCase().contains(query) ||
          r.studentId.toLowerCase().contains(query);
    }).toList();

    switch (_sortBy) {
      case 'lowest_rating':
        filtered.sort((a, b) {
          // Put unrated at the very end
          if (!a.hasRatings && !b.hasRatings) return 0;
          if (!a.hasRatings) return 1;
          if (!b.hasRatings) return -1;
          return a.averageRating!.compareTo(b.averageRating!);
        });
        break;
      case 'most_deliveries':
        filtered.sort((a, b) => b.completedDeliveries.compareTo(a.completedDeliveries));
        break;
      case 'most_reviews':
        filtered.sort((a, b) => b.totalReviews.compareTo(a.totalReviews));
        break;
      case 'highest_rating':
      default:
        filtered.sort((a, b) {
          if (!a.hasRatings && !b.hasRatings) return 0;
          if (!a.hasRatings) return 1;
          if (!b.hasRatings) return -1;
          return b.averageRating!.compareTo(a.averageRating!);
        });
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = DDartTheme.isDark(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryMaroon),
      );
    }

    if (_error != null) {
      return Center(
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
                onPressed: _fetchData,
                style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final totalRunners = _runners.length;
    final totalDeliveries = _runners.fold<int>(0, (sum, r) => sum + r.completedDeliveries);
    final totalReviews = _runners.fold<int>(0, (sum, r) => sum + r.totalReviews);
    final ratedRunners = _runners.where((r) => r.hasRatings).toList();
    final overallAvg = ratedRunners.isNotEmpty
        ? (ratedRunners.fold<double>(0.0, (sum, r) => sum + (r.averageRating ?? 0.0)) / ratedRunners.length)
        : null;

    final sortedFiltered = _getSortedAndFilteredRunners();

    // Top performers (rating >= 4.0, has ratings)
    final topPerformers = _runners.where((r) => r.hasRatings && (r.averageRating ?? 0) >= 4.0).toList()
      ..sort((a, b) => (b.averageRating ?? 0).compareTo(a.averageRating ?? 0));

    // Attention required (has ratings and rating < 3.5)
    final attentionRequired = _runners.where((r) => r.hasRatings && (r.averageRating ?? 0) < 3.5).toList()
      ..sort((a, b) => (a.averageRating ?? 0).compareTo(b.averageRating ?? 0));

    return RefreshIndicator(
      color: primaryMaroon,
      onRefresh: _fetchData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryMaroon.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rate_rounded, color: gold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Runner Ratings & Performance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: DDartTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Monitor delivery quality, ratings, and customer satisfaction',
                      style: TextStyle(
                        fontSize: 12,
                        color: DDartTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh performance data',
                onPressed: _fetchData,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Overall Performance Statistics Cards
          _buildOverallStatsGrid(
            context,
            totalRunners: totalRunners,
            totalDeliveries: totalDeliveries,
            overallAvgRating: overallAvg != null ? '${overallAvg.toStringAsFixed(1)} ★' : 'No Ratings',
            totalReviews: totalReviews,
            isDark: isDark,
          ),
          const SizedBox(height: 20),

          // Highlights: Highest & Lowest Rated Runners
          if (topPerformers.isNotEmpty || attentionRequired.isNotEmpty) ...[
            _buildHighlightsSection(
              context,
              topPerformers: topPerformers.take(3).toList(),
              attentionRequired: attentionRequired.take(3).toList(),
              isDark: isDark,
            ),
            const SizedBox(height: 20),
          ],

          // Search & Sort Bar
          _buildControlsRow(context, isDark),
          const SizedBox(height: 12),

          // Runner Rankings List
          Text(
            'Runner Rankings (${sortedFiltered.length})',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: DDartTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),

          if (sortedFiltered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(
                'No runners match your search or filter.',
                style: TextStyle(color: DDartTheme.textMuted(context)),
              ),
            )
          else
            ...sortedFiltered.map((runner) => _buildRunnerRankingCard(context, runner, isDark)),
        ],
      ),
    );
  }

  Widget _buildOverallStatsGrid(
    BuildContext context, {
    required int totalRunners,
    required int totalDeliveries,
    required String overallAvgRating,
    required int totalReviews,
    required bool isDark,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _buildSummaryCard(
                context,
                title: 'Total Runners',
                value: '$totalRunners',
                icon: Icons.directions_run_rounded,
                iconColor: primaryMaroon,
                subtitle: 'Registered & active',
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildSummaryCard(
                context,
                title: 'Completed Deliveries',
                value: '$totalDeliveries',
                icon: Icons.check_circle_outline_rounded,
                iconColor: Colors.green,
                subtitle: 'Successful handovers',
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildSummaryCard(
                context,
                title: 'Overall Avg Rating',
                value: overallAvgRating,
                icon: Icons.star_rounded,
                iconColor: gold,
                subtitle: 'Customer satisfaction',
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildSummaryCard(
                context,
                title: 'Customer Reviews',
                value: '$totalReviews',
                icon: Icons.reviews_outlined,
                iconColor: Colors.blueAccent,
                subtitle: 'Ratings submitted',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required String subtitle,
  }) {
    return Container(
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
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: DDartTheme.textSecondary(context),
                ),
              ),
              Icon(icon, size: 20, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: DDartTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: DDartTheme.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsSection(
    BuildContext context, {
    required List<RunnerPerformance> topPerformers,
    required List<RunnerPerformance> attentionRequired,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topPerformers.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B281B) : const Color(0xFFF1F8F1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF2E7D32) : const Color(0xFFA5D6A7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: gold, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Highest-Rated Runners',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isDark ? Colors.green.shade300 : Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...topPerformers.map(
                  (r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '• ${r.runnerName}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: DDartTheme.textPrimary(context),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: gold, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${r.ratingDisplay} (${r.totalReviews} reviews, ${r.completedDeliveries} del.)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (attentionRequired.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF381B1B) : const Color(0xFFFFF1F1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF8B2B2B) : const Color(0xFFFFCDD2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Attention Required (Lowest Rated Runners)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isDark ? Colors.red.shade300 : Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...attentionRequired.map(
                  (r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '• ${r.runnerName}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: DDartTheme.textPrimary(context),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${r.ratingDisplay} (${r.totalReviews} reviews)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.red.shade300 : Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildControlsRow(BuildContext context, bool isDark) {
    return Column(
      children: [
        // Search Box
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search runner by name or ID...',
            hintStyle: TextStyle(fontSize: 12.5, color: DDartTheme.textMuted(context)),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                  )
                : null,
            isDense: true,
            filled: true,
            fillColor: DDartTheme.card(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: DDartTheme.border(context)),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
        ),
        const SizedBox(height: 10),

        // Sort Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text(
                'Sort by: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DDartTheme.textSecondary(context),
                ),
              ),
              const SizedBox(width: 4),
              _buildSortChip('Highest Rating', 'highest_rating'),
              const SizedBox(width: 6),
              _buildSortChip('Lowest Rating', 'lowest_rating'),
              const SizedBox(width: 6),
              _buildSortChip('Most Deliveries', 'most_deliveries'),
              const SizedBox(width: 6),
              _buildSortChip('Most Reviews', 'most_reviews'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _sortBy = value);
      },
      selectedColor: primaryMaroon.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? primaryMaroon : DDartTheme.textSecondary(context),
      ),
      side: BorderSide(
        color: isSelected ? primaryMaroon : DDartTheme.border(context),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildRunnerRankingCard(BuildContext context, RunnerPerformance runner, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: DDartTheme.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: DDartTheme.border(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RunnerProfileScreen(
                runnerId: runner.runnerId,
                runnerName: runner.runnerName,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryMaroon,
                  border: Border.all(color: gold.withValues(alpha: 0.5), width: 1.5),
                ),
                child: ClipOval(
                  child: runner.photoUrl != null && runner.photoUrl!.isNotEmpty
                      ? Image.network(
                          runner.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.directions_run_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        )
                      : const Icon(
                          Icons.directions_run_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      runner.runnerName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: DDartTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (runner.studentId.isNotEmpty) ...[
                          Text(
                            'ID: ${runner.studentId} • ',
                            style: TextStyle(
                              fontSize: 11,
                              color: DDartTheme.textMuted(context),
                            ),
                          ),
                        ],
                        Text(
                          '${runner.completedDeliveries} completed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Rating Badge & Action
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (runner.hasRatings) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: gold.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: gold, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${runner.ratingDisplay} ★',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFFFD54F) : const Color(0xFFB78103),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${runner.totalReviews} review${runner.totalReviews > 1 ? "s" : ""}',
                      style: TextStyle(
                        fontSize: 10,
                        color: DDartTheme.textMuted(context),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: DDartTheme.cardSubtle(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'No Ratings Yet',
                        style: TextStyle(
                          fontSize: 10,
                          color: DDartTheme.textMuted(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Inspect',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: DDartTheme.accentText(context),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: DDartTheme.accentText(context),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
