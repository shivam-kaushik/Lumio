import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_smart_card.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_phase.dart';
import '../../data/models/goal_task.dart';
import 'goal_details_screen.dart';

/// Screen for managing roadmap phases for a goal
class RoadmapManagementScreen extends StatefulWidget {
  final int goalId;
  final String goalName;

  const RoadmapManagementScreen({
    super.key,
    required this.goalId,
    required this.goalName,
  });

  @override
  State<RoadmapManagementScreen> createState() => _RoadmapManagementScreenState();
}

class _RoadmapManagementScreenState extends State<RoadmapManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GrowthProvider>().loadGrowthData();
    });
  }

  Future<void> _createPhase() async {
    final goal = context.read<GrowthProvider>().goals.firstWhere(
      (g) => g.id == widget.goalId,
    );

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? startDate = DateTime.now();
    DateTime? endDate = goal.targetDeadline ?? DateTime.now().add(const Duration(days: 30));

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Create Phase'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Phase Name',
                      hintText: 'e.g., Phase 1, Foundation, Development',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  const Text(
                    'Start Date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: goal.targetDeadline ?? DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (date != null) {
                        setState(() => startDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 20, color: AppTheme.textSecondary),
                          const SizedBox(width: AppTheme.spacingSM),
                          Text(
                            startDate != null
                                ? DateFormat('MMM d, y').format(startDate!)
                                : 'Select start date',
                            style: TextStyle(
                              color: startDate != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  const Text(
                    'End Date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: startDate ?? DateTime.now(),
                        lastDate: goal.targetDeadline ?? DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (date != null) {
                        setState(() => endDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 20, color: AppTheme.textSecondary),
                          const SizedBox(width: AppTheme.spacingSM),
                          Text(
                            endDate != null
                                ? DateFormat('MMM d, y').format(endDate!)
                                : 'Select end date',
                            style: TextStyle(
                              color: endDate != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a phase name')),
                    );
                    return;
                  }
                  if (startDate == null || endDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select both start and end dates')),
                    );
                    return;
                  }
                  if (endDate!.isBefore(startDate!)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('End date must be after start date')),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'startDate': startDate,
                    'endDate': endDate,
                  });
                },
                child: const Text('Create'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && mounted) {
      try {
        final phases = context.read<GrowthProvider>().getPhasesForGoal(widget.goalId);
        final phase = GoalPhase(
          id: 0,
          goalId: widget.goalId,
          name: result['name'] as String,
          description: (result['description'] as String).isEmpty ? null : result['description'] as String,
          startDate: result['startDate'] as DateTime,
          endDate: result['endDate'] as DateTime,
          orderIndex: phases.length,
          createdAt: DateTime.now(),
        );
        await context.read<GrowthProvider>().createPhase(phase);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Phase created successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating phase: $e')),
          );
        }
      }
    }
  }

  Future<void> _editPhase(GoalPhase phase) async {
    final nameController = TextEditingController(text: phase.name);
    final descriptionController = TextEditingController(text: phase.description ?? '');
    DateTime? startDate = phase.startDate;
    DateTime? endDate = phase.endDate;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Edit Phase'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Phase Name',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  const Text(
                    'Start Date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (date != null) {
                        setState(() => startDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 20, color: AppTheme.textSecondary),
                          const SizedBox(width: AppTheme.spacingSM),
                          Text(
                            startDate != null
                                ? DateFormat('MMM d, y').format(startDate!)
                                : 'Select start date',
                            style: TextStyle(
                              color: startDate != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  const Text(
                    'End Date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: startDate ?? DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (date != null) {
                        setState(() => endDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 20, color: AppTheme.textSecondary),
                          const SizedBox(width: AppTheme.spacingSM),
                          Text(
                            endDate != null
                                ? DateFormat('MMM d, y').format(endDate!)
                                : 'Select end date',
                            style: TextStyle(
                              color: endDate != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a phase name')),
                    );
                    return;
                  }
                  if (startDate == null || endDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select both start and end dates')),
                    );
                    return;
                  }
                  if (endDate!.isBefore(startDate!)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('End date must be after start date')),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'startDate': startDate,
                    'endDate': endDate,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && mounted) {
      try {
        final updatedPhase = phase.copyWith(
          name: result['name'] as String,
          description: (result['description'] as String).isEmpty ? null : result['description'] as String,
          startDate: result['startDate'] as DateTime,
          endDate: result['endDate'] as DateTime,
        );
        await context.read<GrowthProvider>().updatePhase(updatedPhase);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Phase updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating phase: $e')),
          );
        }
      }
    }
  }

  Future<void> _deletePhase(GoalPhase phase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Phase'),
        content: Text('Are you sure you want to delete "${phase.name}"? Tasks in this phase will be unassigned.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<GrowthProvider>().deletePhase(phase.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Phase deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting phase: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Roadmap: ${widget.goalName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {
              // Navigate to goal details to edit the goal
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GoalDetailsScreen(goalId: widget.goalId),
                ),
              );
            },
            tooltip: 'Edit Goal',
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _createPhase,
            tooltip: 'Create Phase',
          ),
        ],
      ),
      body: Consumer<GrowthProvider>(
        builder: (context, growthProvider, child) {
          final phases = growthProvider.getPhasesForGoal(widget.goalId);
          final tasks = growthProvider.getTasksForGoal(widget.goalId);

          if (phases.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timeline_rounded,
                      size: 80,
                      color: AppTheme.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    Text(
                      'No phases yet',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      'Create phases to organize your goal roadmap',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: AppTheme.spacingXL),
                    ElevatedButton.icon(
                      onPressed: _createPhase,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create First Phase'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingMD,
              AppTheme.spacingMD,
              AppTheme.spacingMD,
              100, // Bottom padding for scrolling
            ),
            itemCount: phases.length,
            itemBuilder: (context, index) {
              final phase = phases[index];
              final phaseTasks = tasks.where((t) => t.phaseId == phase.id).toList();
              final completedCount = phaseTasks.where((t) => t.isCompleted).length;
              final progress = phaseTasks.isNotEmpty ? completedCount / phaseTasks.length : 0.0;

              return ModernSmartCard(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                useGradient: true,
                elevationLevel: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                phase.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (phase.description != null && phase.description!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  phase.description!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppTheme.spacingSM),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: AppTheme.spacingXS),
                                  Text(
                                    '${DateFormat('MMM d').format(phase.startDate)} - ${DateFormat('MMM d, y').format(phase.endDate)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (value) {
                            // Defer action until after popup menu closes
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (value == 'edit') {
                                _editPhase(phase);
                              } else if (value == 'delete') {
                                _deletePhase(phase);
                              }
                            });
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_rounded, size: 20, color: AppTheme.errorColor),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (phaseTasks.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacingMD),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppTheme.borderColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 0.8
                              ? Colors.green
                              : progress >= 0.5
                                  ? Colors.orange
                                  : AppTheme.primaryColor,
                        ),
                        minHeight: 6,
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      Text(
                        '$completedCount of ${phaseTasks.length} tasks completed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: AppTheme.spacingSM),
                      Text(
                        'No tasks assigned yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

