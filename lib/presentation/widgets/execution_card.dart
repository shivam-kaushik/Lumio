import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/goal_task.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';

class ExecutionCard extends StatefulWidget {
  final GoalTask task;

  const ExecutionCard({super.key, required this.task});

  @override
  State<ExecutionCard> createState() => _ExecutionCardState();
}

class _ExecutionCardState extends State<ExecutionCard> {
  late Timer _timer;
  Duration _currentDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateDuration();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateDuration());
  }

  void _updateDuration() {
    if (widget.task.startedAt == null) return;
    
    final sessionDuration = DateTime.now().difference(widget.task.startedAt!);
    final totalDuration = Duration(minutes: widget.task.actualMinutes ?? 0) + sessionDuration;
    
    if (mounted) {
      setState(() => _currentDuration = totalDuration);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.task.startedAt == null) return const SizedBox.shrink(); // Safety

    // Format HH:MM:SS
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(_currentDuration.inHours);
    final minutes = twoDigits(_currentDuration.inMinutes.remainder(60));
    final seconds = twoDigits(_currentDuration.inSeconds.remainder(60));

    return Card(
      elevation: 8,
      shadowColor: AppTheme.primaryColor.withOpacity(0.4),
      color: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Pulse Icon
            const Icon(Icons.circle, color: Colors.redAccent, size: 12),
            const SizedBox(width: 12),
            
            // Task Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "IN FOCUS",
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "$hours:$minutes:$seconds",
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(width: 8),

            // Stop Button
            IconButton(
              onPressed: () {
                context.read<GrowthProvider>().toggleTaskTimer(widget.task.id);
              },
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.white70, size: 32),
            ),
            
            // Check Button
            IconButton(
              onPressed: () {
                 // Stop timer first
                 context.read<GrowthProvider>().toggleTaskTimer(widget.task.id).then((_) {
                   // Then complete
                   if (context.mounted) {
                     context.read<GrowthProvider>().completeTask(widget.task.id);
                   }
                 });
              },
              icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 32),
            ),
          ],
        ),
      ),
    );
  }
}
