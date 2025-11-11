import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/reminder_provider.dart';
import '../widgets/context_group_card.dart';
import '../widgets/smart_reminder_dialog.dart';
import '../theme/app_theme.dart';
import 'add_reminder_screen.dart';
import 'ai_chat_screen.dart';
import '../../data/models/reminder.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/services/home_detection_service.dart';

/// Premium home screen with minimal, elegant design
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _currentPosition;
  String? _currentActivity;
  bool _hideCompleted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderProvider>().loadReminders();
      _updateContext();
    });
  }

  Future<void> _updateContext() async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.whileInUse ||
          hasPermission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentPosition = position;
        });
      }

      final homeService = HomeDetectionService();
    } catch (e) {
      debugPrint('Error updating context: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // No Scaffold here - MainNavigator provides it
    return SafeArea(
      bottom: false, // MainNavigator handles bottom safe area
      child: Column(
        children: [
          // Premium header
          _buildPremiumHeader(context, isDark),
          
          // Main content
          Expanded(
            child: Consumer<ReminderProvider>(
                builder: (context, reminderProvider, child) {
                  if (reminderProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (reminderProvider.error != null) {
                    return _buildErrorState(context, reminderProvider);
                  }

                  if (reminderProvider.reminders.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  final visibleReminders = reminderProvider.reminders;
                         final groups = ReminderUtils.groupByContext(
                           visibleReminders,
                           currentPosition: _currentPosition,
                         );

                  if (groups.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await reminderProvider.loadReminders();
                      await _updateContext();
                    },
                    child: CustomScrollView(
                      slivers: [
                        // Stats header (optional)
                        SliverToBoxAdapter(
                          child: _buildStatsHeader(context, reminderProvider),
                        ),
                        
                        // Reminder groups
                        ...groups.entries.map((entry) {
                          return SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppTheme.spacingMD,
                              0,
                              AppTheme.spacingMD,
                              AppTheme.spacingMD,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: ContextGroupCard(
                                contextTitle: entry.key,
                                reminders: entry.value,
                                contextIcon: ReminderUtils.getContextIcon(entry.key),
                                currentPosition: _currentPosition,
                                onReminderTap: (reminder) async {
                                  final result = await showDialog<Reminder>(
                                    context: context,
                                    builder: (context) => SmartReminderDialog(
                                      reminder: reminder,
                                    ),
                                  );
                                  if (result != null && mounted) {
                                    reminderProvider.updateReminder(result);
                                  }
                                },
                                onToggle: (id, enabled) {
                                  reminderProvider.toggleReminder(id, enabled);
                                },
                                onDelete: (id) {
                                  reminderProvider.deleteReminder(id);
                                },
                              ),
                            ),
                          );
                        }),
                        
                        // Bottom padding above bottom navigation bar
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: 120),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildPremiumHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMD,
        AppTheme.spacingMD,
        AppTheme.spacingMD,
        AppTheme.spacingMD,
      ),
      child: Row(
        children: [
          // Logo/Icon with subtle gradient
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryLight,
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              boxShadow: AppTheme.getElevationShadow(2),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          
          const SizedBox(width: AppTheme.spacingMD),
          
          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Awarely',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Never forget what matters',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          
          // AI Assistant button
          IconButton(
            icon: Icon(
              Icons.smart_toy_rounded,
              color: AppTheme.primaryColor,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AiChatScreen(),
                ),
              );
            },
            tooltip: 'AI Assistant',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context, ReminderProvider provider) {
    final stats = provider.statistics;
    if (stats == null) return const SizedBox.shrink();
    
    final total = stats['total'] ?? 0;
    final active = stats['active'] ?? 0;
    final completionRate = stats['completionRate'] ?? 0;
    
    if (total == 0) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacingMD,
        AppTheme.spacingSM,
        AppTheme.spacingMD,
        AppTheme.spacingMD,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.borderColor, width: 1),
        boxShadow: AppTheme.getElevationShadow(1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(context, '$active', 'Active'),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.dividerColor,
          ),
          Expanded(
            child: _buildStatItem(
              context,
              '$completionRate%',
              'Completed',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.dividerColor,
          ),
          Expanded(
            child: _buildStatItem(context, '$total', 'Total'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_rounded,
                size: 64,
                color: AppTheme.primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            Text(
              'No reminders yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              'Create your first smart reminder\nto get started',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddReminderScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Create Reminder'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXL,
                  vertical: AppTheme.spacingMD,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ReminderProvider provider,
  ) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppTheme.errorColor.withOpacity(0.7),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              'Something went wrong',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              provider.error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton(
              onPressed: () {
                provider.loadReminders();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

}
