import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/context_event.dart';
import '../../data/models/reminder.dart';
import '../../data/repositories/firestore_reminder_repository.dart';

/// Recent Notifications - lists context events (notification triggers)
class RecentNotificationsScreen extends StatefulWidget {
  const RecentNotificationsScreen({super.key});

  @override
  State<RecentNotificationsScreen> createState() =>
      _RecentNotificationsScreenState();
}

class _RecentNotificationsScreenState extends State<RecentNotificationsScreen> {
  final FirestoreReminderRepository _repo = FirestoreReminderRepository();
  List<ContextEvent> _events = [];
  Map<String, Reminder> _reminders = {}; // Cache reminders
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final events = await _repo.getAllContextEvents();

      // Load reminders for all events
      final reminderIds = events.map((e) => e.reminderId).toSet();
      final reminderMap = <String, Reminder>{};

      for (final id in reminderIds) {
        final reminder = await _repo.getReminder(id);
        if (reminder != null) {
          reminderMap[id] = reminder;
        }
      }

      setState(() {
        _events = events;
        _reminders = reminderMap;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Failed to load context events: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markSeen(ContextEvent event) async {
    try {
      await _repo.updateContextEventOutcome(event.id, AppConstants.outcomeSeen);
      await _loadEvents();
    } catch (e) {
      // ignore: avoid_print
      print('Failed to mark event seen: $e');
    }
  }

  Widget _buildEventCard(ContextEvent e) {
    final timeLabel = e.triggerTime.toLocal().toString();
    final reminder = _reminders[e.reminderId];
    final reminderText = reminder?.text ?? 'Reminder not found';

    final subtitle = <String>[];
    subtitle.add('Context: ${e.contextType}');
    if (e.metadata != null) subtitle.add('Data: ${e.metadata}');
    subtitle.add('Outcome: ${e.outcome}');

    // Color code based on outcome
    Color? cardColor;
    IconData? icon;
    if (e.outcome == AppConstants.outcomeSeen) {
      cardColor = Colors.green.shade50;
      icon = Icons.check_circle;
    } else if (e.outcome == AppConstants.outcomePending) {
      cardColor = Colors.blue.shade50;
      icon = Icons.schedule;
    } else if (e.outcome == AppConstants.outcomeMissed) {
      cardColor = Colors.orange.shade50;
      icon = Icons.warning_amber;
    }

    return Card(
      color: cardColor,
      child: ListTile(
        leading: icon != null ? Icon(icon, color: Colors.grey.shade700) : null,
        title: Text(
          reminderText,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle.join(' • '), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              'Time: $timeLabel',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: e.outcome == AppConstants.outcomeSeen
            ? const Icon(Icons.check, color: Colors.green)
            : e.outcome == AppConstants.outcomePending
                ? const Icon(Icons.timer, color: Colors.blue)
                : TextButton(
                    onPressed: () => _markSeen(e),
                    child: const Text('Mark seen'),
                  ),
        onTap: () {
          // Show details dialog
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Notification Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reminder: $reminderText'),
                  const SizedBox(height: 8),
                  Text('Context: ${e.contextType}'),
                  Text('Outcome: ${e.outcome}'),
                  Text('Triggered at: $timeLabel'),
                  if (e.metadata != null) Text('Data: ${e.metadata}'),
                ],
              ),
              actions: [
                if (e.outcome != AppConstants.outcomeSeen &&
                    e.outcome != AppConstants.outcomePending)
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _markSeen(e);
                    },
                    child: const Text('Mark seen'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _events.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text('No recent notifications')),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _events.length,
                    itemBuilder: (c, i) => _buildEventCard(_events[i]),
                  ),
      ),
    );
  }
}
