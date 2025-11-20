import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/reminder_provider.dart';
import '../../core/services/weekly_insights_service.dart';
import '../../data/repositories/firestore_reminder_repository.dart';
import '../theme/app_theme.dart';

/// Analytics screen showing completion statistics and weekly insights
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  WeeklyInsightsService? _insightsService;
  Map<String, dynamic>? _weeklyTrends;
  List<Map<String, dynamic>>? _insights;
  bool _loadingInsights = true;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _loadingInsights = true);
    try {
      final repository = FirestoreReminderRepository();
      _insightsService = WeeklyInsightsService(repository);
      
      final trends = await _insightsService!.getWeeklyCompletionTrends();
      final generatedInsights = await _insightsService!.generateInsights();
      
      if (mounted) {
        setState(() {
          _weeklyTrends = trends;
          _insights = generatedInsights;
          _loadingInsights = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading insights: $e');
      if (mounted) {
        setState(() => _loadingInsights = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // No Scaffold - MainNavigator provides it
    return Column(
      children: [
        // Custom AppBar
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: AppTheme.spacingLG,
            right: AppTheme.spacingMD,
            bottom: AppTheme.spacingMD,
          ),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            border: Border(
              bottom: BorderSide(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Analytics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: AppTheme.textSecondary,
                ),
                onPressed: _loadInsights,
                tooltip: 'Refresh insights',
              ),
            ],
          ),
        ),
        // Body content
        Expanded(
          child: Consumer<ReminderProvider>(
            builder: (context, reminderProvider, child) {
              final stats = reminderProvider.statistics;

              if (stats == null) {
                return const Center(child: CircularProgressIndicator());
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingLG,
                  AppTheme.spacingLG,
                  AppTheme.spacingLG,
                  120, // prevent content behind bottom nav bar
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Completion rate card - Premium design
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryLight,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(AppTheme.spacingXL),
                  child: Column(
                    children: [
                      Text(
                        '${stats['completionRate'] ?? 0}%',
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      Text(
                        'Completion Rate',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacingLG),

                // Stats grid - Premium cards
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppTheme.spacingMD,
                  crossAxisSpacing: AppTheme.spacingMD,
                  children: [
                    _buildStatCard(
                      context,
                      'Total Reminders',
                      '${stats['totalReminders'] ?? 0}',
                      Icons.notifications_rounded,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      context,
                      'Active',
                      '${stats['activeReminders'] ?? 0}',
                      Icons.check_circle_rounded,
                      Colors.green,
                    ),
                    _buildStatCard(
                      context,
                      'Completed',
                      '${stats['completedEvents'] ?? 0}',
                      Icons.done_all_rounded,
                      Colors.purple,
                    ),
                    _buildStatCard(
                      context,
                      'Total Events',
                      '${stats['totalEvents'] ?? 0}',
                      Icons.timeline_rounded,
                      Colors.orange,
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacingXL),

                // Insights section header
                Text(
                  'Insights',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: AppTheme.spacingMD),

                // Weekly Trends Section
                if (_loadingInsights)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  if (_weeklyTrends != null) ...[
                    _buildWeeklyTrendsCard(context, _weeklyTrends!),
                    const SizedBox(height: 16),
                  ],
                  
                  if (_insights != null && _insights!.isNotEmpty) ...[
                    Text(
                      'Insights',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ..._insights!.map((insight) => _buildInsightCard(
                      context,
                      insight['title'] as String,
                      insight['description'] as String,
                      _getInsightIcon(insight['icon'] as String),
                      insight['type'] as String,
                    )),
                  ],
                ],
                // Bottom spacer to ensure scrollable area above nav bar
                const SizedBox(height: 16),
              ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyTrendsCard(BuildContext context, Map<String, dynamic> trends) {
    final trendsList = trends['trends'] as List;
    final averageRate = trends['averageCompletionRate'] as int;
    final trendValue = trends['trend'] as int;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        side: const BorderSide(color: AppTheme.borderColor, width: 1),
      ),
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Trends',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (trendValue != 0)
                  Chip(
                    avatar: Icon(
                      trendValue > 0 ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                    ),
                    label: Text(
                      '${trendValue > 0 ? "+" : ""}$trendValue%',
                      style: TextStyle(
                        color: trendValue > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (trendsList.isEmpty)
              const Text('Not enough data yet. Keep using reminders to see trends!')
            else ...[
              Text(
                'Average: $averageRate%',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              // Simple bar chart
              ...trendsList.take(4).map((week) {
                final rate = week['completionRate'] as int;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            week['week'] as String,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '$rate%',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: rate / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            rate >= 70 ? Colors.green : rate >= 50 ? Colors.orange : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getInsightIcon(String iconString) {
    switch (iconString) {
      case '📈':
        return Icons.trending_up;
      case '📉':
        return Icons.trending_down;
      case '⏰':
        return Icons.access_time;
      case '⭐':
        return Icons.star;
      case '💪':
        return Icons.fitness_center;
      default:
        return Icons.lightbulb;
    }
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        side: const BorderSide(color: AppTheme.borderColor, width: 1),
      ),
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingSM),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    String type,
  ) {
    Color backgroundColor;
    Color iconColor;
    
    switch (type) {
      case 'positive':
        backgroundColor = AppTheme.successColor.withOpacity(0.1);
        iconColor = AppTheme.successColor;
        break;
      case 'warning':
        backgroundColor = AppTheme.warningColor.withOpacity(0.1);
        iconColor = AppTheme.warningColor;
        break;
      default:
        backgroundColor = AppTheme.primaryColor.withOpacity(0.1);
        iconColor = AppTheme.primaryColor;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        side: const BorderSide(color: AppTheme.borderColor, width: 1),
      ),
      color: AppTheme.surfaceColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMD,
          vertical: AppTheme.spacingSM,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppTheme.spacingXS),
          child: Text(
            description,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
