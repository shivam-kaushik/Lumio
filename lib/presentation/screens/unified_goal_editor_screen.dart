import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/premium_service.dart'; // Add PremiumService import
import '../models/plan_block.dart';
import '../theme/app_theme.dart';
import '../providers/growth_provider.dart';
import '../../core/services/privacy_gpt_service.dart';
import '../../data/models/goal_task.dart';
import 'dart:async'; // Add async for Timer
import '../../data/models/subtask.dart' show Task;
import '../../data/models/goal.dart';

class UnifiedGoalEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? aiResult; // Nullable now
  final Goal? existingGoal; // For editing existing
  final List<GoalTask>? initialTasks; // Changed from List<Task> to List<GoalTask>
  final bool isNew; 

  const UnifiedGoalEditorScreen({
    super.key,
    this.aiResult, // Optional
    this.existingGoal,
    this.initialTasks,
    this.isNew = true,
  });

  @override
  State<UnifiedGoalEditorScreen> createState() => _UnifiedGoalEditorScreenState();
}

class _UnifiedGoalEditorScreenState extends State<UnifiedGoalEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final List<PlanBlock> _blocks = [];
  bool _isSaving = false;
  bool _isGeneratingSubtasks = false; 
  Timer? _debounce; // For auto-save
  DateTime? _goalDeadline; // NEW: Local deadline state
  int? _localGoalId; // NEW: Track ID of locally created goal (for "new" goals that become "existing" mid-session)

  @override
  void initState() {
    super.initState();
    if (widget.existingGoal != null) {
      _titleController.text = widget.existingGoal!.name;
      _goalDeadline = widget.existingGoal!.targetDeadline; // Load existing
      _loadExistingGoal();
    } else if (widget.aiResult != null) {
      _parseAiResult();
    } else {
      _titleController.text = ""; // Empty for new
      _goalDeadline = DateTime.now().add(const Duration(days: 30)); // Default 30 days
    }
  }

  void _loadExistingGoal() {
    final g = widget.existingGoal!;
    // Note: Removed redundant text block for deadline since we have UI for it now
    if (widget.initialTasks != null && widget.initialTasks!.isNotEmpty) {
        _flattenTasks(widget.initialTasks!, 0);
    } else {
        _blocks.add(PlanBlock.text("No tasks yet. Add one below!"));
    }
  }

  // Recursive helper to flatten tasks for UI
  void _flattenTasks(List<GoalTask> tasks, int indent) {
    for (var t in tasks) {
         _blocks.add(PlanBlock.task(
             t.title,
             indentationLevel: indent, 
             isChecked: t.isCompleted,
             metadata: {
                 'id': t.id, 
                 'description': t.description,
                 'priority': t.priority,
                 'estimatedHours': t.estimatedHours,
                 'suggestedTime': t.suggestedTime,
                 'scheduledDate': t.scheduledDate?.toIso8601String(),
             }
         ));
         // Recursively add subtasks
         if (t.subtasks.isNotEmpty) {
           _flattenTasks(t.subtasks, indent + 1);
         }
    }
  }

  // ... _parseAiResult ...
  void _parseAiResult() {
    final data = widget.aiResult!;
    
    // 1. Goal Title
    if (data['goal'] != null) {
      _titleController.text = data['goal'];
    }

    // 2. Deadline/Context (as text)
    if (data['deadline'] != null) {
        // Parse deadline
        String deadlineStr = data['deadline'].toString();
        try {
            final dt = DateTime.parse(deadlineStr);
            deadlineStr = 'Target: ${dt.month}/${dt.day}/${dt.year}';
        } catch (_) {}
      _blocks.add(PlanBlock.text("📅 $deadlineStr"));
    }

    // 3. Tasks
    if (data['tasks'] != null) {
      final tasks = data['tasks'] as List;
      for (var taskMap in tasks) {
        _blocks.add(PlanBlock.task(
          taskMap['title'] ?? 'Untitled Task',
          metadata: taskMap,
        ));
      }
    }
  }

  void _triggerAutoSave() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
        if (mounted && _titleController.text.isNotEmpty) {
            _savePlan(silent: true);
        }
    });
  }

  // Helper to build nested tree from flat blocks
  List<GoalTask> _buildTaskTree(int goalId) {
     final List<Map<String, dynamic>> rootMaps = [];
     final Map<int, Map<String, dynamic>> lastParentAtLevel = {};
     int orderCounter = 0;
     // Base timestamp for generating unique IDs in this batch
     // Using microseconds to reduce collision chance, plus counter
     final int baseTimestamp = DateTime.now().millisecondsSinceEpoch;

     for (var block in _blocks) {
        if (block.type != BlockType.task || block.content.isEmpty) continue;

        final meta = block.metadata ?? {};
        // CRITICAL FIX: Ensure valid integer ID. If from AI (fake ID) or null, generate new one.
        // We assume valid DB IDs are large timestamps. Small numbers from AI are treated as null.
        int? taskId = meta['id'] as int?;
        if (taskId != null && taskId < 1000000000) { 
            // Likely a fake AI placeholder ID (like 1, 2, 3) -> Reset it
            taskId = null; 
        }

        // Generate a truly unique ID if needed
        // Use baseTimestamp + orderCounter to ensure distinct IDs even if loop is fast
        final int effectiveId = taskId ?? (baseTimestamp + orderCounter);
        
        // Mutable map structure
        final Map<String, dynamic> taskMap = {
             'id': effectiveId, 
             'goal_id': goalId,
             'title': block.content,
             'description': meta['description'] ?? block.content,
             'is_completed': block.isChecked ? 1 : 0,
             'estimated_hours': (meta['estimatedHours'] as num?)?.toDouble() ?? 1.0,
             'priority': meta['priority'] ?? 'medium',
             'scheduled_date': meta['scheduledDate'],
             'created_at': DateTime.now().toIso8601String(),
             'order_index': orderCounter++,
             'indent_level': block.indentationLevel, // Persist indentation level too
             'subtasks': <Map<String, dynamic>>[], // Initialize list for recursion
        };

        if (block.indentationLevel == 0) {
             rootMaps.add(taskMap);
             lastParentAtLevel[0] = taskMap;
        } else {
             // Find parent
             // Ideally parent is at indent - 1.
             // Robustness: If indent jumped (e.g. 0 -> 2), attach to nearest parent (indent 0).
             int parentLevel = block.indentationLevel - 1;
             while (parentLevel >= 0 && !lastParentAtLevel.containsKey(parentLevel)) {
                 parentLevel--;
             }

             if (parentLevel >= 0) {
                 final parent = lastParentAtLevel[parentLevel];
                 (parent!['subtasks'] as List).add(taskMap);
                 lastParentAtLevel[block.indentationLevel] = taskMap;
             } else {
                 // Fallback: Treat as root if no parent found
                 rootMaps.add(taskMap);
                 lastParentAtLevel[block.indentationLevel] = taskMap;
             }
        }
     }

     // Convert Maps back to GoalTasks
     return rootMaps.map((m) => GoalTask.fromMap(m)).toList();
  }

  Future<void> _savePlan({bool silent = false}) async {
    // Prevent duplicate saves or empty titles
    if (_titleController.text.isEmpty) return; 

    if (!silent) setState(() => _isSaving = true);
    
    try {
      final growthProvider = context.read<GrowthProvider>();
      
      String goalName = _titleController.text;

      // Determine effective ID: Use local ID if we created one, otherwise use existing
      final effectiveGoalId = _localGoalId ?? widget.existingGoal?.id;

      // 1. Create OR Update Goal
      int goalId;
      if (effectiveGoalId == null) {
         // Create New Goal (Auto-create)
         goalId = await growthProvider.createGoal(
            goalName,
            targetDeadline: _goalDeadline ?? DateTime.now().add(const Duration(days: 30)), 
         );
         _localGoalId = goalId; // Store for future updates
      } else {
         // Update Existing Goal
         goalId = effectiveGoalId;
         // We need the original goal object to update safely
         // If we have widget.existingGoal, use it. If not (it was local), fetch or construct minimal.
         final baseGoal = widget.existingGoal ?? 
             Goal(id: goalId, name: goalName, createdAt: DateTime.now()); // Minimal fallback

         await growthProvider.updateGoal(baseGoal.copyWith(
            name: goalName,
            targetDeadline: _goalDeadline,
         ));
      }

      // 2. Build Tree and Replace Tasks
      final rootTasks = _buildTaskTree(goalId);
      
      // 3. Save to Backend (Recursive)
      await growthProvider.replaceTasksForGoal(goalId, rootTasks);
      
      if (!silent && mounted) {
        // Only show if explicit manual save (which we are removing, but good for safety)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!")));
        if (widget.isNew) Navigator.of(context).pop(); 
      }
    } catch (e) {
       debugPrint("Save error: $e");
    } finally {
      if (mounted && !silent) setState(() => _isSaving = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Use app theme
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : AppTheme.backgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor, 

      appBar: AppBar(
        title: Text(widget.isNew ? "Create Goal" : "Edit Goal", style: TextStyle(color: textColor)),
        backgroundColor: backgroundColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        actions: [
            // Status Indicator (Optional)
            if (_isSaving) 
                const Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            if (!_isSaving && (_localGoalId != null || widget.existingGoal != null))
                const Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: Icon(Icons.cloud_done, color: Colors.green, size: 20), // "Saved" icon
                ),
        ],
      ),
      body: PopScope(
        canPop: true,
        onPopInvoked: (didPop) async {
             if (didPop) {
                 // Trigger final save if we have pending changes or just to be safe
                 if (_titleController.text.isNotEmpty) {
                    await _savePlan(silent: true);
                 }
             }
        },
        child: Consumer<GrowthProvider>(
        builder: (context, growthProvider, child) {


          return Stack(
            children: [
                Column(
                  children: [
                    // FIXED HEADER: Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _titleController,
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
                              decoration: const InputDecoration(
                                border: InputBorder.none, 
                                hintText: "Goal Title", 
                                hintStyle: TextStyle(color: Colors.grey),
                              ),
                              onChanged: (v) => _triggerAutoSave(),
                              maxLines: null,
                            ),
                          ),
                          // Goal-level Deadline Picker
                          IconButton(
                            icon: Icon(Icons.calendar_month, color: isDark ? Colors.white70 : AppTheme.primaryColor, size: 24),
                            tooltip: _goalDeadline != null 
                                ? "Deadline: ${_goalDeadline!.month}/${_goalDeadline!.day}/${_goalDeadline!.year}" 
                                : "Set Deadline",
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _goalDeadline ?? DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                              );
                              if (picked != null) {
                                setState(() => _goalDeadline = picked);
                                _triggerAutoSave();
                              }
                            },
                          ),
                          // Goal-level AI Action
                          PopupMenuButton<String>(
                            icon: Icon(Icons.auto_awesome, color: isDark ? Colors.white70 : AppTheme.primaryColor, size: 24),
                            onSelected: (value) {
                                 if (value == 'generate_tasks') _generateTasksForGoal();
                            },
                            itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'generate_tasks', 
                                  child: Row(
                                    children: [
                                      Icon(Icons.checklist, size: 20, color: Colors.purple), 
                                      SizedBox(width: 8), 
                                      Text("Generate Tasks")
                                    ]
                                  )
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), // Bottom padding for FAB
                          itemCount: _blocks.length + 1, 
                          onReorder: (oldIndex, newIndex) {
                              if (oldIndex >= _blocks.length || newIndex > _blocks.length) return;
                              setState(() {
                                  if (oldIndex < newIndex) newIndex -= 1;
                                  final item = _blocks.removeAt(oldIndex);
                                  _blocks.insert(newIndex, item);
                              });
                          },
                          itemBuilder: (context, index) {
                              if (index == _blocks.length) {
                                  return _buildAddBlockButton(key: const ValueKey('add_btn'));
                              }
                              return _buildBlock(_blocks[index], index, textColor);
                          },
                      ),
                    ),
                  ],
                ),
                
                // AI Floating Action Button (The "Face")
                Positioned(
                bottom: 24,
                right: 24,
                child: FloatingActionButton(
                    backgroundColor: isDark ? Colors.white : AppTheme.primaryColor,
                    child: Icon(Icons.auto_awesome, color: isDark ? Colors.black : Colors.white),
                    onPressed: () {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tap a task's menu to generate subtasks!")));
                    },
                ),
            ),
            
            if (_isGeneratingSubtasks)
                Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                ),
        ],
      );
    },
  ),
  ),
    );
  }

  Widget _buildBlock(PlanBlock block, int index, Color textColor) {
    // Indentation logic
    final indent = block.indentationLevel * 32.0;
    
    // Check for deadline in metadata
    final deadlineStr = block.metadata?['scheduledDate'];
    DateTime? deadline;
    if (deadlineStr != null) deadline = DateTime.tryParse(deadlineStr);

    return Padding(
        key: ValueKey(block.id),
        padding: EdgeInsets.only(left: indent, bottom: 8),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                if (block.type == BlockType.task) ...[
                     // Checkbox
                     InkWell(
                         onTap: () {
                             setState(() => block.isChecked = !block.isChecked);
                             _triggerAutoSave();
                         },
                         child: Padding(
                             padding: const EdgeInsets.only(top: 10, right: 8),
                             child: Icon(
                                 block.isChecked ? Icons.check_box : Icons.check_box_outline_blank, 
                                 color: block.isChecked ? AppTheme.primaryColor : Colors.grey,
                                 size: (block.indentationLevel > 0) ? 18 : 20,
                             ),
                         ),
                     ),
                ] else if (block.type == BlockType.text) ...[
                     const Padding(padding: EdgeInsets.only(top: 12, right: 8), child: Icon(Icons.short_text, color: Colors.grey, size: 16)),
                ],

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBlockContent(block, textColor),
                      
                      // Task Deadline & Info Row
                      if (block.type == BlockType.task)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: InkWell(
                            onTap: () async {
                               // Open Date Picker
                               final date = await showDatePicker(
                                 context: context, 
                                 initialDate: deadline ?? DateTime.now(), 
                                 firstDate: DateTime.now(), 
                                 lastDate: DateTime.now().add(const Duration(days: 365 * 5))
                               );
                               if (date != null) {
                                   setState(() {
                                       block.metadata ??= {};
                                       block.metadata!['scheduledDate'] = date.toIso8601String();
                                   });
                                   _triggerAutoSave();
                               }
                            },
                            child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: (deadline != null) ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                    border: (deadline == null) ? Border.all(color: Colors.grey.withOpacity(0.3)) : null,
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        Icon(Icons.calendar_today, size: 12, color: (deadline != null) ? AppTheme.primaryColor : Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                            (deadline != null) ? "${deadline.month}/${deadline.day}" : "Set Deadline",
                                            style: TextStyle(
                                                fontSize: 12, 
                                                color: (deadline != null) ? AppTheme.primaryColor : Colors.grey
                                            ),
                                        ),
                                    ],
                                ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Actions Menu (for AI)
                if (block.type == BlockType.task)
                    PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
                        onSelected: (value) {
                             if (value == 'ai_subtasks') _generateSubtasksFor(block, index);
                             if (value == 'delete') setState(() => _blocks.removeAt(index));
                             if (value == 'indent') setState(() => block.indentationLevel = (block.indentationLevel + 1) % 4);
                        },
                        itemBuilder: (context) => [
                            const PopupMenuItem(value: 'ai_subtasks', child: Row(children: [Icon(Icons.auto_awesome, size: 16, color: Colors.purple), SizedBox(width: 8), Text("Generate Subtasks")])),
                            const PopupMenuItem(value: 'indent', child: Row(children: [Icon(Icons.format_indent_increase, size: 16), SizedBox(width: 8), Text("Cycle Indent")])),
                            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text("Delete")])),
                        ],
                    ),
                // Drag Handle
                ReorderableDragStartListener(
                    index: index,
                    child: const Padding(padding: EdgeInsets.only(top: 12), child: Icon(Icons.drag_indicator, size: 20, color: Colors.grey)),
                ),
            ],
        ),
    );
  }

  Widget _buildBlockContent(PlanBlock block, Color textColor) {
    final isSubtask = block.indentationLevel > 0;
    final fontSize = isSubtask ? 14.0 : 16.0;

    // Note: Heading is removed from here since it's above the list now
    if (block.type == BlockType.text) {
         return TextFormField(
            initialValue: block.content,
            style: TextStyle(fontSize: fontSize, color: textColor.withOpacity(0.7), height: 1.5),
            decoration: const InputDecoration(border: InputBorder.none, hintText: "Overview/Context...", hintStyle: TextStyle(color: Colors.grey)),
            onChanged: (v) { block.content = v; _triggerAutoSave(); },
            maxLines: null,
        );
    } else {
         // Task
         return TextFormField(
            initialValue: block.content,
            style: TextStyle(
                fontSize: fontSize, 
                fontWeight: isSubtask ? FontWeight.normal : FontWeight.w500, // Bold root tasks
                color: block.isChecked ? textColor.withOpacity(0.3) : textColor, 
                decoration: block.isChecked ? TextDecoration.lineThrough : null,
                decorationColor: textColor.withOpacity(0.3),
            ),
            decoration: InputDecoration(
                border: InputBorder.none, 
                hintText: isSubtask ? "Subtask name" : "Task name", 
                hintStyle: TextStyle(color: Colors.grey.withOpacity(isSubtask ? 0.7 : 1.0), fontSize: fontSize)
            ),
            onChanged: (v) { block.content = v; _triggerAutoSave(); },
            maxLines: null,
         );
    }
  }

  // Generate tasks for the main Goal
  Future<void> _generateTasksForGoal() async {
       if (_titleController.text.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a goal title first")));
         return;
       }

       // Check Premium
       final isPremium = await PremiumService().isPremium();
       if (!isPremium) {
         if (mounted) _showPremiumLock(context);
         return;
       }

       setState(() => _isGeneratingSubtasks = true);
       
       try {
           final service = PrivacyGptService();
           // Break down the main goal
           final subtasks = await service.breakDownTask("Goal: ${_titleController.text}");

           // Calculate dates
           final now = DateTime.now();
           final goalDeadline = widget.existingGoal?.targetDeadline ?? now.add(const Duration(days: 30));
           final totalDays = goalDeadline.difference(now).inDays;
           final daysPerTask = (totalDays / (subtasks.isEmpty ? 1 : subtasks.length)).floor(); // Simple distribution

           setState(() {
               // Append new tasks to the end
               for (var i = 0; i < subtasks.length; i++) {
                   final s = subtasks[i];
                   final cleanMetadata = Map<String, dynamic>.from(s)..remove('id'); // Remove potential AI fake IDs
                   
                   // Assign date
                   final taskDeadline = now.add(Duration(days: (i + 1) * daysPerTask));
                   cleanMetadata['scheduledDate'] = taskDeadline.toIso8601String();

                   _blocks.add(PlanBlock.task(
                       s['title'] ?? 'Task', 
                       indentationLevel: 0, // Top level
                       metadata: cleanMetadata
                   ));
               }
           });
           
           _triggerAutoSave(); // Save changes
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added ${subtasks.length} tasks!")));

       } catch (e) {
           debugPrint("Error generating properties: $e");
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to generate tasks")));
       } finally {
            if (mounted) setState(() => _isGeneratingSubtasks = false);
       }
  }

  // Placeholder for AI generation
  Future<void> _generateSubtasksFor(PlanBlock parentBlock, int index) async {
       // Check Premium
       final isPremium = await PremiumService().isPremium();
       if (!isPremium) {
         if (mounted) _showPremiumLock(context);
         return;
       }

       setState(() => _isGeneratingSubtasks = true);
       
       try {
           final service = PrivacyGptService();
           // Use the new method name 'breakDownTask'
           final subtasks = await service.breakDownTask(parentBlock.content);

           // Determine Parent Date Context
           final now = DateTime.now();
           DateTime parentDeadline = now.add(const Duration(days: 30)); // Default fallback
           if (parentBlock.metadata != null && parentBlock.metadata!['scheduledDate'] != null) {
                try {
                    parentDeadline = DateTime.parse(parentBlock.metadata!['scheduledDate']);
                } catch (_) {}
           } else if (widget.existingGoal?.targetDeadline != null) {
                // If parent has no date, upper bound is goal deadline
                parentDeadline = widget.existingGoal!.targetDeadline!;
           }

           final totalDays = parentDeadline.difference(now).inDays;
           // Ensure at least 1 day per subtask if possible, or distribute tight
           final daysAvailable = totalDays > 0 ? totalDays : 1;
           final double daysPerSubtask = daysAvailable / (subtasks.isEmpty ? 1 : subtasks.length);

           setState(() {
               int currentLevel = parentBlock.indentationLevel + 1;
               // Insert subtasks
               for (var i = 0; i < subtasks.length; i++) {
                   final s = subtasks[i];
                   final cleanMetadata = Map<String, dynamic>.from(s)..remove('id'); // Remove potential AI fake IDs
                   
                   // Calculate Subtask Deadline
                   // It should be strictly BEFORE or ON the parent deadline
                   // We spread them out leading up to it
                   final offsetDays = ((i + 1) * daysPerSubtask).floor();
                   final subtaskDeadline = now.add(Duration(days: offsetDays));
                   
                   // Safety clamp: Ensure it doesn't exceed parent deadline
                   final finalDate = subtaskDeadline.isAfter(parentDeadline) ? parentDeadline : subtaskDeadline;
                   cleanMetadata['scheduledDate'] = finalDate.toIso8601String();

                   _blocks.insert(index + 1 + i, PlanBlock.task(
                       s['title'] ?? 'Subtask', 
                       indentationLevel: currentLevel,
                       metadata: cleanMetadata
                   ));
               }
           });
           
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Generated ${subtasks.length} subtasks!")));

       } catch (e) {
           debugPrint("Error generating subtasks: $e");
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to generate subtasks")));
       } finally {
            if (mounted) setState(() => _isGeneratingSubtasks = false);
       }
  }

  void _showPremiumLock(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.lock, color: Colors.orange), SizedBox(width: 8), Text("Premium Feature")]),
        content: const Text("AI-powered task generation is available for Premium users only. Upgrade to unlock!"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Maybe Later")),
          ElevatedButton(
            onPressed: () {
               Navigator.pop(context);
               // TODO: Navigate to paywall
            }, 
            child: const Text("Upgrade Now")
          ),
        ],
      ),
    );
  }

  Widget _buildAddBlockButton({required Key key}) {
      return Container(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
              child: IconButton(
                  icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 32),
                  onPressed: () {
                      setState(() {
                          _blocks.add(PlanBlock.task("New Task"));
                      });
                  },
              ),
          ),
      );
  }
}
