import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/context_event.dart';
import '../../data/models/goal_task.dart';
import '../../data/models/reminder.dart';
import '../../data/repositories/firestore_reminder_repository.dart';
import '../../data/repositories/firestore_growth_repository.dart';
import '../theme/theme.dart';
import 'day_planner_screen.dart';
import 'goal_details_screen.dart';
import '../utils/analytics_helper.dart';

class NotificationViewModel {
  final ContextEvent event;
  final String title;
  final String body;
  final String type;
  final dynamic relatedObject;

  NotificationViewModel({
    required this.event,
    required this.title,
    required this.body,
    required this.type,
    this.relatedObject,
  });
}

/// Notification history screen — Stitch-style bottom sheet design, max 6 items.
class RecentNotificationsScreen extends StatefulWidget {
  const RecentNotificationsScreen({super.key});

  @override
  State<RecentNotificationsScreen> createState() => _RecentNotificationsScreenState();
}

class _RecentNotificationsScreenState extends State<RecentNotificationsScreen> {
  final FirestoreReminderRepository _reminderRepo = FirestoreReminderRepository();
  final FirestoreGrowthRepository _growthRepo = FirestoreGrowthRepository();

  List<NotificationViewModel> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final events = await _reminderRepo.getRecentTriggeredEvents();
      final List<NotificationViewModel> viewModels = [];
      for (final event in events) {
        viewModels.add(await _resolveEvent(event));
        if (viewModels.length >= 6) break; // Max 6
      }
      setState(() => _notifications = viewModels);
    } catch (e) {
      debugPrint('Error loading notification events: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<NotificationViewModel> _resolveEvent(ContextEvent e) async {
    final meta = e.metadata ?? {};
    String title = meta['title'] as String? ?? '';
    String body = meta['body'] as String? ?? '';
    String type = meta['type'] as String? ?? 'unknown';
    dynamic relatedObject;

    Future<void> resolveTask(String idStr) async {
      final taskId = int.tryParse(idStr);
      if (taskId != null) {
        final task = await _growthRepo.getTaskById(taskId);
        if (task != null) {
          title = task.title;
          body = 'Task reminder';
          type = 'task_notification';
          relatedObject = task;
        } else {
          if (title.isEmpty || title == 'Notification') title = 'Completed Task';
          body = 'This task is no longer active';
        }
      }
    }

    if (title.isNotEmpty && title != 'Notification' && body.isNotEmpty) {
      return NotificationViewModel(event: e, title: title, body: body, type: type);
    }

    try {
      if (e.reminderId.startsWith('task_')) {
        await resolveTask(e.reminderId.replaceFirst('task_', ''));
      } else if (e.reminderId.isNotEmpty) {
        bool resolvedFromJson = false;
        if (e.reminderId.trim().startsWith('{')) {
          try {
            final json = jsonDecode(e.reminderId);
            if (json is Map && json.containsKey('task_id')) {
              await resolveTask(json['task_id'].toString());
              resolvedFromJson = true;
              if (type == 'unknown') type = 'task_notification';
            }
          } catch (_) {}
        }
        if (!resolvedFromJson) {
          final reminder = await _reminderRepo.getReminder(e.reminderId);
          if (reminder != null) {
            title = reminder.text;
            body = 'Reminder';
            type = 'reminder_alarm';
            relatedObject = reminder;
          } else {
            if (title.isEmpty || title == 'Notification') title = 'Reminder';
          }
        }
      }
    } catch (err) {
      debugPrint('Error resolving notification ${e.id}: $err');
    }

    if (title.isEmpty) title = 'Notification';
    if (body.isEmpty) body = 'Scheduled for ${_formatTimeShort(e.triggerTime)}';

    return NotificationViewModel(
      event: e, title: title, body: body, type: type, relatedObject: relatedObject,
    );
  }

  void _handleTap(NotificationViewModel vm) async {
    if (vm.relatedObject is GoalTask) {
      final task = vm.relatedObject as GoalTask;
      try {
        final goal = await _growthRepo.getGoal(task.goalId);
        if (goal != null) {
          if (goal.name.startsWith('Daily Plan')) {
            final dateToCheck = task.scheduledDate ?? task.createdAt;
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => AnalyticsHelper.isSameDay(dateToCheck, DateTime.now())
                  ? const DayPlannerScreen()
                  : DayPlannerScreen(initialDate: dateToCheck),
            ));
            return;
          }
          if (goal.name == 'Inbox') {
            Navigator.pop(context);
            return;
          }
        }
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => GoalDetailsScreen(goalId: task.goalId),
        ));
      } catch (_) {
        Navigator.pop(context);
      }
      return;
    }

    if (vm.event.metadata?.containsKey('goal_id') == true) {
      final goalId = vm.event.metadata!['goal_id'];
      if (goalId != null) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => GoalDetailsScreen(
            goalId: goalId is int ? goalId : int.tryParse(goalId.toString()) ?? 0,
          ),
        ));
        return;
      }
    }

    if (vm.type == 'reminder_alarm' || vm.relatedObject is Reminder) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DayPlannerScreen()));
    }
  }

  // ── Type → visual config ─────────────────────────────────────────────────

  _NotifStyle _styleFor(NotificationViewModel vm) {
    switch (vm.type) {
      case 'motivational':
        return _NotifStyle(
          icon: Icons.auto_awesome_rounded,
          color: LumioColors.primary,
          bg: LumioColors.primaryLight,
          label: 'AI INSIGHT',
        );
      case 'task_notification':
        return _NotifStyle(
          icon: Icons.schedule_rounded,
          color: Colors.blue.shade600,
          bg: Colors.blue.shade50,
          label: 'TASK REMINDER',
        );
      case 'reminder_alarm':
        return _NotifStyle(
          icon: Icons.alarm_rounded,
          color: Colors.blue.shade600,
          bg: Colors.blue.shade50,
          label: 'REMINDER',
        );
      default:
        // Check if it looks like a goal milestone
        if (vm.title.toLowerCase().contains('milestone') ||
            vm.title.toLowerCase().contains('achieved') ||
            vm.title.toLowerCase().contains('reached')) {
          return _NotifStyle(
            icon: Icons.emoji_events_rounded,
            color: Colors.green.shade600,
            bg: Colors.green.shade50,
            label: 'GOAL MILESTONE',
          );
        }
        return _NotifStyle(
          icon: Icons.lightbulb_outline_rounded,
          color: Colors.grey.shade500,
          bg: Colors.grey.shade100,
          label: 'TIP',
        );
    }
  }

  // ── Time formatting ───────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.isNegative) {
      final f = diff.abs();
      if (f.inMinutes < 60) return 'in ${f.inMinutes}m';
      if (f.inHours < 24) return 'in ${f.inHours}h';
      return '${dt.month}/${dt.day}';
    }

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (AnalyticsHelper.isSameDay(dt, yesterday)) {
      return 'Yesterday';
    }

    final today = DateTime(now.year, now.month, now.day);
    if (dt.isAfter(today)) {
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = h >= 12 ? 'PM' : 'AM';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return 'Today, $hour12:$m $ampm';
    }

    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatTimeShort(DateTime dt) =>
      '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF2D2418) : const Color(0xFFF5F0EB);
    final handleColor = isDark ? Colors.white12 : Colors.black12;

    return Scaffold(
      backgroundColor: sheetBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle (visual)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: LumioTypography.headlineSmall.copyWith(
                        color: LumioColors.textPrimary(context),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  // Close / back button
                  Material(
                    color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.5),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: LumioColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Content
            Expanded(
              child: _loading
                  ? _buildLoading(context)
                  : _notifications.isEmpty
                      ? _buildEmpty(context)
                      : _buildList(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      itemBuilder: (_, i) => _ShimmerCard(delay: i * 100),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: LumioColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_outlined, size: 48, color: LumioColors.primary),
          ),
          const SizedBox(height: 20),
          Text('No notifications yet', style: LumioTypography.titleMedium.copyWith(color: LumioColors.textPrimary(context))),
          const SizedBox(height: 8),
          Text('They\'ll appear here when triggered', style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textSecondary(context))),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: _notifications.length,
      itemBuilder: (ctx, i) => _buildCard(_notifications[i], context, isDark, i),
    );
  }

  Widget _buildCard(NotificationViewModel vm, BuildContext context, bool isDark, int index) {
    final style = _styleFor(vm);
    final timeStr = _formatTime(vm.event.triggerTime);
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.65);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: () => _handleTap(vm),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored icon badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? style.color.withValues(alpha: 0.2) : style.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(style.icon, color: style.color, size: 24),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category label + time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        style.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: style.color.withValues(alpha: 0.85),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: LumioTypography.labelSmall.copyWith(
                          color: LumioColors.textSecondary(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Title / body
                  Text(
                    vm.title,
                    style: LumioTypography.bodyMedium.copyWith(
                      color: LumioColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (vm.body.isNotEmpty && vm.body != vm.title) ...[
                    const SizedBox(height: 3),
                    Text(
                      vm.body,
                      style: LumioTypography.bodySmall.copyWith(
                        color: LumioColors.textSecondary(context),
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      )
          .animate(delay: (index * 60).ms)
          .fadeIn(duration: 350.ms)
          .slideY(begin: 0.08, end: 0, duration: 350.ms, curve: Curves.easeOut),
    );
  }
}

// ── Visual config for a notification type ────────────────────────────────────

class _NotifStyle {
  final IconData icon;
  final Color color;
  final Color bg;
  final String label;

  const _NotifStyle({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
  });
}

// ── Shimmer placeholder card ──────────────────────────────────────────────────

class _ShimmerCard extends StatefulWidget {
  final int delay;
  const _ShimmerCard({required this.delay});

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _anim.value * 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: LumioColors.primary.withValues(alpha: _anim.value * 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 10, width: 80, decoration: BoxDecoration(color: LumioColors.primary.withValues(alpha: _anim.value * 0.4), borderRadius: BorderRadius.circular(5))),
                  const SizedBox(height: 8),
                  Container(height: 14, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: _anim.value * 0.3), borderRadius: BorderRadius.circular(5))),
                  const SizedBox(height: 6),
                  Container(height: 12, width: 160, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: _anim.value * 0.2), borderRadius: BorderRadius.circular(5))),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: widget.delay.ms)
        .fadeIn(duration: 200.ms);
  }
}
