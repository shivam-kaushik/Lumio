import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/goal_task.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';

/// A robust, interactive circular timer for active tasks
class ActiveTaskTimer extends StatefulWidget {
  final GoalTask task;
  final VoidCallback? onStop;
  final VoidCallback? onComplete;

  const ActiveTaskTimer({
    super.key, 
    required this.task,
    this.onStop,
    this.onComplete,
  });

  @override
  State<ActiveTaskTimer> createState() => _ActiveTaskTimerState();
}

class _ActiveTaskTimerState extends State<ActiveTaskTimer> with SingleTickerProviderStateMixin {
  late Timer _timer;
  Duration _currentDuration = Duration.zero;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: 2.seconds)..repeat();
    _updateDuration();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateDuration());
  }

  void _updateDuration() {
    if (widget.task.startedAt == null) {
        if (_animController.isAnimating) _animController.stop();
        return;
    }
    
    if (!_animController.isAnimating) _animController.repeat();

    final sessionDuration = DateTime.now().difference(widget.task.startedAt!);
    final totalDuration = Duration(minutes: widget.task.actualMinutes ?? 0) + sessionDuration;
    
    if (mounted) {
      setState(() => _currentDuration = totalDuration);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.task.startedAt == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Formatting
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(_currentDuration.inHours);
    final minutes = twoDigits(_currentDuration.inMinutes.remainder(60));
    final seconds = twoDigits(_currentDuration.inSeconds.remainder(60));

    // Progress (Arbitrary 60m goal for visual circle if not set)
    final totalEstMinutes = widget.task.estimatedMinutes ?? 60;
    final progress = (_currentDuration.inMinutes / math.max(1, totalEstMinutes)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E20) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            // Header
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(
                                "CURRENTLY FOCUSING ON",
                                style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 1.2
                                ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                                width: 200,
                                child: Text(
                                    widget.task.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                    ),
                                ),
                            ),
                        ],
                    ),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20)
                        ),
                        child: Row(
                            children: [
                                const Icon(Icons.bolt_rounded, size: 16, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                    "${widget.task.efficiencyScore}% Eff.",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                )
                            ],
                        ),
                    )
                ],
            ),

            const SizedBox(height: 32),

            // Circular Timer
            SizedBox(
                height: 220,
                width: 220,
                child: Stack(
                    alignment: Alignment.center,
                    children: [
                        // Background Circle
                        SizedBox(
                            height: 220,
                            width: 220,
                            child: CircularProgressIndicator(
                                value: 1.0,
                                strokeWidth: 12,
                                color: isDark ? Colors.white10 : Colors.grey[200],
                            ),
                        ),
                        // Progress Circle
                        SizedBox(
                            height: 220,
                            width: 220,
                            child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 12,
                                color: AppTheme.primaryColor,
                                strokeCap: StrokeCap.round,
                            ),
                        ),
                        // Pulse Effect
                        if (widget.task.startedAt != null)
                             AnimatedBuilder(
                                animation: _animController,
                                builder: (context, child) {
                                    return Container(
                                        height: 180 + (_animController.value * 10),
                                        width: 180 + (_animController.value * 10),
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1 * (1 - _animController.value)), width: 2)
                                        ),
                                    );
                                },
                             ),

                        // Time Text
                        Text(
                            "$hours:$minutes:$seconds",
                            style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                height: 1,
                                fontFeatures: [FontFeature.tabularFigures()], 
                            ),
                        ),
                    ],
                ),
            ),
            
            const SizedBox(height: 32),

            // Controls
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    // Restart (Reset)
                     _ControlButton(
                         icon: Icons.replay_rounded,
                         color: Colors.redAccent,
                         label: "Restart",
                         onTap: () {
                             context.read<GrowthProvider>().restartTask(widget.task.id);
                         },
                     ),
                     const SizedBox(width: 24),
                     // Pause
                     _ControlButton(
                         icon: Icons.pause_rounded,
                         color: Colors.orangeAccent,
                         label: "Pause",
                         onTap: () {
                             context.read<GrowthProvider>().toggleTaskTimer(widget.task.id);
                             widget.onStop?.call();
                         },
                     ),
                     const SizedBox(width: 24),
                     // Finish
                     _ControlButton(
                         icon: Icons.check_rounded,
                         color: Colors.green,
                         label: "Done",
                         isLarge: true,
                         onTap: () {
                             context.read<GrowthProvider>().toggleTaskTimer(widget.task.id).then((_) {
                                 if (context.mounted) {
                                     context.read<GrowthProvider>().completeTask(widget.task.id);
                                     widget.onComplete?.call();
                                 }
                             });
                         },
                     ),
                ],
            ),
        ],
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }
}

class _ControlButton extends StatelessWidget {
    final IconData icon;
    final Color color;
    final String label;
    final VoidCallback onTap;
    final bool isLarge;

    const _ControlButton({
        required this.icon,
        required this.color,
        required this.label,
        required this.onTap,
        this.isLarge = false,
    });

    @override
    Widget build(BuildContext context) {
        return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                        padding: EdgeInsets.all(isLarge ? 24 : 16),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: color.withOpacity(0.5), width: 2)
                        ),
                        child: Icon(icon, color: color, size: isLarge ? 32 : 24),
                    ),
                ),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))
            ],
        );
    }
}
