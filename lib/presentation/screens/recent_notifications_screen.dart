import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/context_event.dart';
import '../../data/models/goal_task.dart';
import '../../data/models/reminder.dart';
import '../../data/repositories/firestore_reminder_repository.dart';
import '../../data/repositories/firestore_growth_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_smart_card.dart';
import 'day_planner_screen.dart';
import 'goal_details_screen.dart'; 
import '../navigation/main_navigator.dart'; // Add import
import '../utils/analytics_helper.dart'; // Add import

/// Model to hold resolved notification data for display
class NotificationViewModel {
  final ContextEvent event;
  final String title;
  final String body;
  final String type;
  final dynamic relatedObject; // Task or Reminder

  NotificationViewModel({
    required this.event,
    required this.title,
    required this.body,
    required this.type,
    this.relatedObject,
  });
}

/// Recent Notifications - history of all triggers (Tasks, Goals, Reminders)
class RecentNotificationsScreen extends StatefulWidget {
  const RecentNotificationsScreen({super.key});

  @override
  State<RecentNotificationsScreen> createState() =>
      _RecentNotificationsScreenState();
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
      final events = await _reminderRepo.getAllContextEvents();
      // Sort by triggerTime descending (newest first)
      events.sort((a, b) => b.triggerTime.compareTo(a.triggerTime));
      
      final List<NotificationViewModel> viewModels = [];
      
      for (final event in events) {
        final vm = await _resolveEvent(event);
        viewModels.add(vm);
      }
      
      setState(() {
        _notifications = viewModels;
      });
    } catch (e) {
      debugPrint('Error loading events: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Resolve event details (fetch Task/Reminder if metadata missing)
  Future<NotificationViewModel> _resolveEvent(ContextEvent e) async {
    final meta = e.metadata ?? {};
    String title = meta['title'] as String? ?? '';
    String body = meta['body'] as String? ?? '';
    String type = meta['type'] as String? ?? 'unknown';
    dynamic relatedObject;

    // Helper to fetch task
    Future<void> resolveTask(String idStr) async {
        final taskId = int.tryParse(idStr);
        if (taskId != null) {
          final task = await _growthRepo.getTaskById(taskId);
          if (task != null) {
             title = task.title;
             body = 'Task • ${_formatTimeShort(e.triggerTime)}';
             type = 'task_notification';
             relatedObject = task;
          } else {
             // Handle deleted task gracefully
             // Try to use metadata title if available, effectively falling back to what was recorded at trigger time
             if (title.isEmpty || title == 'Notification') {
                 title = 'Completed or Deleted Task';
             }
             body = 'This task is no longer active';
          }
        }
    }

    // If metadata is rich, use it (Fast path)
    if (title.isNotEmpty && title != 'Notification' && body.isNotEmpty) {
      return NotificationViewModel(
        event: e,
        title: title,
        body: body,
        type: type,
      );
    }
    
    // Slow path: Resolve from ID
    try {
      if (e.reminderId.startsWith('task_')) {
        // It's a Task
        await resolveTask(e.reminderId.replaceFirst('task_', ''));
      } else if (e.reminderId.isNotEmpty) {
         // Check for Legacy JSON Bug (ID stored as JSON string)
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
            // It's a Reminder
            final reminder = await _reminderRepo.getReminder(e.reminderId);
            if (reminder != null) {
               title = reminder.text;
               body = 'Reminder • ${_formatTimeShort(e.triggerTime)}';
               type = 'reminder_alarm';
               relatedObject = reminder;
            } else {
               // Maybe it's a legacy generic ID or deleted
               if (title.isEmpty || title == 'Notification') title = 'Reminder';
            }
        }
      }
    } catch (err) {
      debugPrint('Error resolving notification ${e.id}: $err');
    }

    // Final Fallbacks ensuring non-null values
    if (title.isEmpty) title = 'Notification';
    if (body.isEmpty) body = 'Scheduled for ${_formatTimeShort(e.triggerTime)}';

    return NotificationViewModel(
      event: e,
      title: title,
      body: body,
      type: type,
      relatedObject: relatedObject,
    );
  }

  /// Handle tap on a notification card
  void _handleTap(NotificationViewModel vm) async {
    // 1. Task Navigation
    if (vm.relatedObject is GoalTask) {
       final task = vm.relatedObject as GoalTask;
       
       try {
         final goal = await _growthRepo.getGoal(task.goalId);
         
         if (goal != null) {
             // A. Daily Plan Logic
             if (goal.name.startsWith('Daily Plan')) {
                 // Check if it's from a past day
                 final dateToCheck = task.scheduledDate ?? task.createdAt; 
                 if (!AnalyticsHelper.isSameDay(dateToCheck, DateTime.now())) {
                     // Redirect to Day Planner's History for that specific date
                     Navigator.push(context, MaterialPageRoute(
                       builder: (_) => DayPlannerScreen(initialDate: dateToCheck),
                     ));
                 } else {
                     // It's Today's plan
                     Navigator.push(context, MaterialPageRoute(
                       builder: (_) => const DayPlannerScreen(),
                     ));
                 }
                 return;
             }
             
             // B. Inbox / Home Screen Logic
             if (goal.name == 'Inbox') {
                 // Redirect to Home Screen directly (Resetting stack to avoid confusion)
                 Navigator.pushAndRemoveUntil(
                   context, 
                   MaterialPageRoute(builder: (_) => const MainNavigator()), 
                   (route) => false
                 );
                 return;
             }
         }
         
         // C. Default Goal Details
         Navigator.push(context, MaterialPageRoute(
           builder: (_) => GoalDetailsScreen(goalId: task.goalId),
         ));
       } catch (e) {
         // Fallback if goal fetch fails: Go to Home as safest default
           Navigator.pushAndRemoveUntil(
             context, 
             MaterialPageRoute(builder: (_) => const MainNavigator()), 
             (route) => false
           );
       }
       return;
    }
    
    // ... (rest of method) ...
    
    // 2. Goal ID in metadata (Legacy or Motivational)
    if (vm.event.metadata?.containsKey('goal_id') == true) {
        final goalId = vm.event.metadata!['goal_id'];
        if (goalId != null) {
           Navigator.push(context, MaterialPageRoute(
             builder: (_) => GoalDetailsScreen(
               goalId: goalId is int ? goalId : int.tryParse(goalId.toString()) ?? 0
             ),
           ));
           return;
        }
    }

    // 3. Reminder Navigation
    // Navigate to DayPlanner as it shows reminders
    if (vm.type == 'reminder_alarm' || vm.relatedObject is Reminder) {
        Navigator.push(context, MaterialPageRoute(
           builder: (_) => const DayPlannerScreen(),
        ));
        return;
    }

    // 4. Default Details Dialog
    _showDetailsDialog(vm);
  }

  void _showDetailsDialog(NotificationViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(vm.title),
        content: Text(vm.body),
        actions: [
          TextButton(
             onPressed: () => Navigator.pop(ctx),
             child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(NotificationViewModel vm) {
    final theme = Theme.of(context);
    final timeStr = _formatTime(vm.event.triggerTime);
    
    IconData icon = Icons.notifications_outlined;
    Color iconColor = AppTheme.primaryColor;

    if (vm.type == 'motivational') {
       icon = Icons.emoji_events_rounded;
       iconColor = Colors.amber;
    } else if (vm.type == 'reminder_alarm' || vm.relatedObject is Reminder) {
       icon = Icons.access_time_rounded;
       iconColor = AppTheme.secondaryColor;
    } else if (vm.type == 'task_notification' || vm.relatedObject is GoalTask) {
       icon = Icons.check_circle_outline_rounded;
       iconColor = AppTheme.primaryColor;
    } else if (vm.type == 'immediate') {
       icon = Icons.bolt_rounded;
       iconColor = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ModernSmartCard(
        elevationLevel: 0,
        useGradient: false,
        child: InkWell(
          onTap: () => _handleTap(vm),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Expanded(
                             child: Text(
                               vm.title,
                               style: theme.textTheme.titleSmall?.copyWith(
                                 fontWeight: FontWeight.bold,
                               ),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                           Text(
                             timeStr,
                             style: theme.textTheme.bodySmall?.copyWith(
                               color: AppTheme.textTertiary,
                               fontSize: 10,
                             ),
                           ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vm.body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Arrow
                Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  String _formatTime(DateTime dt) {
     final now = DateTime.now();
     final diff = now.difference(dt);
     
     // Future time handling
     if (diff.isNegative) {
       final futureDiff = diff.abs();
       if (futureDiff.inMinutes < 60) return 'in ${futureDiff.inMinutes}m';
       if (futureDiff.inHours < 24) return 'in ${futureDiff.inHours}h';
       return '${dt.month}/${dt.day}';
     }

     // Past time handling
     if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
     if (diff.inHours < 24) return '${diff.inHours}h ago';
     return '${dt.month}/${dt.day}';
  }

  String _formatTimeShort(DateTime dt) {
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Notifications History'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: AppTheme.textTertiary),
                      const SizedBox(height: 16),
                      Text('No notifications yet', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  itemCount: _notifications.length,
                  itemBuilder: (ctx, i) => _buildEventCard(_notifications[i]),
                ),
    );
  }
}
