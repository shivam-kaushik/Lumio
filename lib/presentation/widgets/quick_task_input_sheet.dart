import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// A smart TextEditingController that highlights keywords
class SmartTextEditingController extends TextEditingController {
  final Map<RegExp, TextStyle> patternMap;

  SmartTextEditingController({required this.patternMap, String? text}) : super(text: text);

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    List<TextSpan> children = [];
    
    // Simple word-based highlighting (tokenization by space)
    final words = text.splitAll(RegExp(r'(\s+)'));
    
    for (var word in words) {
        TextStyle? matchStyle;
        for (var entry in patternMap.entries) {
            if (entry.key.hasMatch(word)) {
                matchStyle = entry.value;
                break;
            }
        }
        children.add(TextSpan(text: word, style: matchStyle?.merge(style) ?? style));
    }

    return TextSpan(style: style, children: children);
  }
}

extension SplitAll on String {
  List<String> splitAll(RegExp pattern) {
    List<String> result = [];
    int start = 0;
    for (var match in pattern.allMatches(this)) {
      if (match.start > start) {
        result.add(substring(start, match.start));
      }
      result.add(substring(match.start, match.end));
      start = match.end;
    }
    if (start < length) {
      result.add(substring(start));
    }
    return result;
  }
}

class QuickTaskInputSheet extends StatefulWidget {
  final Function(
    String title,
    DateTime? date,
    String priority,
    List<String> tags,
    String? repeat,     // daily, weekly, etc.
  ) onSubmit;

  final String? initialTitle;
  final String? initialPriority;
  final List<String>? initialTags;
  final String? initialRepeat;
  final DateTime? initialDate;
  final bool isEditing;

  const QuickTaskInputSheet({
    super.key,
    required this.onSubmit,
    this.initialTitle,
    this.initialPriority,
    this.initialTags,
    this.initialRepeat,
    this.initialDate,
    this.isEditing = false,
  });

  @override
  State<QuickTaskInputSheet> createState() => _QuickTaskInputSheetState();
}

class _QuickTaskInputSheetState extends State<QuickTaskInputSheet> with TickerProviderStateMixin {
  late SmartTextEditingController _controller;
  
  // Parsed State
  DateTime? _parsedDate;
  TimeOfDay? _parsedTime;
  String _parsedPriority = 'medium'; 
  final Set<String> _manualTags = {}; // Tags added via UI
  final Set<String> _textTags = {};   // Tags detected in text
  
  // Combined getter for all tags
  List<String> get _allTags => {..._manualTags, ..._textTags}.toList();

  String? _parsedRepeat;
  
  // Regex Patterns
  static final _datePattern = RegExp(r'\b(today|tomorrow|mon|tue|wed|thu|fri|sat|sun)\b', caseSensitive: false);
  static final _priorityPattern = RegExp(r'(!high|!medium|!low|!p[1-3])', caseSensitive: false);
  static final _tagPattern = RegExp(r'(#[a-zA-Z0-9_]+)', caseSensitive: false);
  // Simple time regex: 5pm, 5:30pm, 5.30pm, 14:00, 14.30
  static final _timePattern = RegExp(r'\b((1[0-2]|0?[1-9])([:.][0-5][0-9])?\s*(am|pm)|([01]?[0-9]|2[0-3])[:.][0-5][0-9])\b', caseSensitive: false);

  @override
  void initState() {
    super.initState();
    _controller = SmartTextEditingController(
      patternMap: {
        _datePattern: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        _timePattern: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
        _priorityPattern: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        _tagPattern: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
      },
    );
    // Initialize state from props if editing
    if (widget.initialTitle != null) {
        _controller.text = widget.initialTitle!;
    }
    if (widget.initialPriority != null) {
        _parsedPriority = widget.initialPriority!;
    }
    if (widget.initialTags != null) {
        // Add valid tags to manual tags
        for (final tag in widget.initialTags!) {
            final checkTag = tag.startsWith('#') ? tag : '#$tag';
            _manualTags.add(checkTag);
        }
    }

    if (widget.initialRepeat != null) {
        _parsedRepeat = widget.initialRepeat;
    }
    if (widget.initialDate != null) {
        _parsedDate = widget.initialDate;
    }

    _controller.addListener(_parseText);
  }

  void _parseText() {
    final text = _controller.text;
    
    // We check detecting NEW info, but we shouldn't overwrite manually set info 
    // unless the user explicitly types it. 
    // For this simple version, typing overrides manual.

    DateTime? newDate = _parsedDate;
    TimeOfDay? newTime = _parsedTime;
    String newPriority = _parsedPriority;
    Set<String> newTextTags = {};

    // 1. Date Detection
    final dateMatch = _datePattern.firstMatch(text);
    if (dateMatch != null) {
        final d = dateMatch.group(0)!.toLowerCase();
        final now = DateTime.now();
        if (d == 'today') newDate = now;
        else if (d == 'tomorrow') newDate = now.add(const Duration(days: 1));
        // Add basic weekday logic if needed
    }

    // 2. Time Detection
    final timeMatch = _timePattern.firstMatch(text);
    if (timeMatch != null) {
        try {
            var tStr = timeMatch.group(0)!.toLowerCase().replaceAll(' ', '');
            // Normalize dot to colon
            tStr = tStr.replaceAll('.', ':');
            
            if (tStr.contains('am') || tStr.contains('pm')) {
                // 12-hour format
                final isPm = tStr.contains('pm');
                final timePart = tStr.replaceAll(RegExp('[a-z]'), '');
                final parts = timePart.split(':');
                int h = int.parse(parts[0]);
                int m = parts.length > 1 ? int.parse(parts[1]) : 0;
                if (isPm && h < 12) h += 12;
                if (!isPm && h == 12) h = 0;
                newTime = TimeOfDay(hour: h, minute: m);
            } else {
                // 24-hour format
                final parts = tStr.split(':');
                newTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
            }
        } catch (_) {}
    }

    // 3. Priority
    final prioMatch = _priorityPattern.firstMatch(text);
    if (prioMatch != null) {
        final p = prioMatch.group(0)!.toLowerCase();
        if (p.contains('high') || p == '!p1') newPriority = 'high';
        else if (p.contains('low') || p == '!p3') newPriority = 'low';
        else newPriority = 'medium';
    }

    // 4. Tags
    final tagMatches = _tagPattern.allMatches(text);
    for (var m in tagMatches) {
        newTextTags.add(m.group(0)!);
    }

    // Update state only if changed to avoid rebuild loops if we were more complex
    // Note: We need to compare sets effectively
    bool tagsChanged = newTextTags.length != _textTags.length || !newTextTags.containsAll(_textTags);

    if (newDate != _parsedDate || newTime != _parsedTime || newPriority != _parsedPriority || tagsChanged) {
       setState(() {
           _parsedDate = newDate;
           _parsedTime = newTime;
           _parsedPriority = newPriority;
           _textTags.clear();
           _textTags.addAll(newTextTags);
       });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    
    // Clean text for final title
    String cleanTitle = _controller.text;
    String originalTitle = cleanTitle; // Backup
    
    // User Update: STRIP tags from title for display cleanliness.
    // They are preserved in the 'tags' list metadata.
    cleanTitle = cleanTitle.replaceAll(_priorityPattern, '')
                           .replaceAll(_tagPattern, ''); 
    
    cleanTitle = cleanTitle.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // If cleaning removed everything (e.g. user just typed "Tomorrow"), revert to original
    if (cleanTitle.isEmpty && originalTitle.trim().isNotEmpty) {
        cleanTitle = originalTitle.trim();
    }

    // Combine Date + Time
    DateTime? finalDate = _parsedDate;
    if (_parsedDate != null && _parsedTime != null) {
        finalDate = DateTime(
            _parsedDate!.year, _parsedDate!.month, _parsedDate!.day,
            _parsedTime!.hour, _parsedTime!.minute
        );
    } else if (_parsedDate == null && _parsedTime != null) {
        // Assume today if time provided but no date
        final now = DateTime.now();
        finalDate = DateTime(now.year, now.month, now.day, _parsedTime!.hour, _parsedTime!.minute);
        if (finalDate.isBefore(now)) {
            // If time passed, assume tomorrow? Or just keep today. Let's keep today.
        }
    }

    widget.onSubmit(cleanTitle, finalDate, _parsedPriority, _allTags, _parsedRepeat);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        bottom: keyboardHeight, 
        left: 0, 
        right: 0,
        top: 0,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0,-2))
        ]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
             child: Container(
               width: 40, 
               height: 4, 
               margin: const EdgeInsets.symmetric(vertical: 12),
               decoration: BoxDecoration(
                 color: isDark ? Colors.grey[700] : Colors.grey[300],
                 borderRadius: BorderRadius.circular(2),
               ),
             ),
          ),

          // Title Prompt
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
               children: [
                   Icon(Icons.edit_note_rounded, size: 20, color: AppTheme.primaryColor).animate().fadeIn(),
                   const SizedBox(width: 8),
                   Text(
                       widget.isEditing ? "Edit Task" : "What's on your mind?", 
                       style: theme.textTheme.titleMedium?.copyWith(
                           color: isDark ? Colors.grey[400] : Colors.grey[600],
                           fontWeight: FontWeight.w600
                       ),
                   ),
               ],
            ),
          ),
          
          // Input Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
               controller: _controller,
               autofocus: true,
               maxLines: 3,
               minLines: 1,
               style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.3),
               decoration: InputDecoration(
                   hintText: 'e.g., Gym at 6pm !high #health',
                   hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                   border: InputBorder.none,
               ),
               onSubmitted: (_) => _submit(),
            ),
          ),

          // Smart Detected Chips (Animated)
          AnimatedContainer(
            duration: 300.ms,
            height: (_parsedDate != null || _parsedTime != null || _parsedRepeat != null || _allTags.isNotEmpty || true) ? 40 : 0,
            child: SingleChildScrollView(
                 scrollDirection: Axis.horizontal,
                 padding: const EdgeInsets.symmetric(horizontal: 16),
                 child: Row(
                    children: [
                        if (_parsedDate != null)
                            _InfoChip(
                                icon: Icons.calendar_today,
                                label: DateFormat('MMM d').format(_parsedDate!),
                                color: Colors.blue,
                            ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
                        if (_parsedTime != null)
                            _InfoChip(
                                icon: Icons.access_time_rounded,
                                label: _parsedTime!.format(context),
                                color: Colors.deepPurple,
                            ).animate().scale(duration: 200.ms, delay: 50.ms, curve: Curves.easeOutBack),
                        if (_parsedRepeat != null)
                             _InfoChip(
                                icon: Icons.repeat_rounded,
                                label: _parsedRepeat!,
                                color: Colors.teal,
                            ).animate().scale(duration: 200.ms, delay: 100.ms),
                        _InfoChip(
                            icon: Icons.flag, 
                            label: _parsedPriority.toUpperCase(),
                            color: _parsedPriority == 'high' ? Colors.red : (_parsedPriority == 'low' ? Colors.blueGrey : Colors.orange),
                        ).animate().scale(duration: 200.ms, delay: 100.ms),
                        ..._allTags.map((t) => _InfoChip(
                            icon: Icons.tag, 
                            label: t.replaceAll('#', ''), 
                            color: Colors.green,
                            onDeleted: () {
                                setState(() {
                                    // If it's a manual tag, remove it directly
                                    if (_manualTags.contains(t)) {
                                        _manualTags.remove(t);
                                    }
                                    // If it's in the text, we might want to remove it from text? 
                                    // For now, let's just remove manual ones via chip tap.
                                    // Removing from text is harder because we need to know WHICH instance to remove.
                                    // So we only support removing manual tags via chip.
                                    // If user wants to remove text tag, they delete text.
                                });
                            },
                        ).animate().scale(duration: 200.ms)),
                    ],
                 ),
             ),
          ),

          const Divider(height: 1),

          // Enhanced Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: isDark ? Colors.black26 : Colors.grey[50],
            child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                   // 1. Date/Time Picker
                   IconButton(
                       icon: Icon(Icons.calendar_month_rounded, color: (_parsedDate != null || _parsedTime != null) ? Colors.blue : null),
                       tooltip: 'Date & Time',
                       onPressed: () async {
                           final date = await showDatePicker(
                               context: context, 
                               initialDate: DateTime.now(), 
                               firstDate: DateTime.now(), 
                               lastDate: DateTime.now().add(const Duration(days: 365)),
                           );
                           if (date != null) {
                               setState(() => _parsedDate = date);
                               if (context.mounted) {
                                   final time = await showTimePicker(
                                       context: context,
                                       initialTime: TimeOfDay.now(),
                                   );
                                   if (time != null) setState(() => _parsedTime = time);
                               }
                           }
                       },
                   ),
                   // 2. Priority Menu
                   PopupMenuButton<String>(
                       icon: Icon(Icons.flag_rounded, color: _parsedPriority == 'high' ? Colors.red : (_parsedPriority == 'low' ? Colors.blueGrey : null)),
                       tooltip: 'Priority',
                       onSelected: (v) => setState(() => _parsedPriority = v),
                       itemBuilder: (context) => [
                           const PopupMenuItem(value: 'high', child: Row(children: [Icon(Icons.flag, color: Colors.red), SizedBox(width: 8), Text("High Priority")])),
                           const PopupMenuItem(value: 'medium', child: Row(children: [Icon(Icons.flag, color: Colors.orange), SizedBox(width: 8), Text("Medium Priority")])),
                           const PopupMenuItem(value: 'low', child: Row(children: [Icon(Icons.flag, color: Colors.blueGrey), SizedBox(width: 8), Text("Low Priority")])),
                       ],
                   ),
                   // 3. Tags (Category)
                   PopupMenuButton<String>(
                       icon: const Icon(Icons.tag_rounded),
                       tooltip: 'Tags',
                       onSelected: (v) {
                           setState(() {
                               _manualTags.add('#$v');
                           });
                           // Explicitly ensure we do NOT touch _controller.text here
                       },
                       itemBuilder: (context) => [
                           const PopupMenuItem(value: 'work', child: Row(children: [Text("💼 Work")])),
                           const PopupMenuItem(value: 'personal', child: Row(children: [Text("🏠 Personal")])),
                           const PopupMenuItem(value: 'shopping', child: Row(children: [Text("🛒 Shopping")])),
                           const PopupMenuItem(value: 'fitness', child: Row(children: [Text("💪 Fitness")])),
                           const PopupMenuItem(value: 'study', child: Row(children: [Text("📚 Study")])),
                           const PopupMenuItem(value: 'finance', child: Row(children: [Text("💰 Finance")])),
                       ],
                   ),
                   // 4. Repeat (Cyclic)
                   PopupMenuButton<String>(
                       icon: Icon(Icons.repeat_rounded, color: _parsedRepeat != null ? Colors.teal : null),
                       tooltip: 'Repeat',
                       onSelected: (v) => setState(() => _parsedRepeat = v == 'none' ? null : v),
                       itemBuilder: (context) => [
                           const PopupMenuItem(value: 'none', child: Text("No Repeat")),
                           const PopupMenuItem(value: 'daily', child: Text("Daily")),
                           const PopupMenuItem(value: 'weekly', child: Text("Weekly")),
                           const PopupMenuItem(value: 'monthly', child: Text("Monthly")),
                       ],
                   ),
                   const Spacer(),
                   
                   // Submit using Send Icon (more standard for chat-like input)
                   Container(
                       margin: const EdgeInsets.only(left: 8),
                       decoration: BoxDecoration(
                           color: AppTheme.primaryColor,
                           shape: BoxShape.circle,
                           boxShadow: [
                               BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
                           ]
                       ),
                       child: IconButton(
                           icon: Icon(
                               widget.isEditing ? Icons.check_rounded : Icons.arrow_upward_rounded, 
                               color: Colors.white
                           ),
                           onPressed: _submit,
                       ),
                   ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
               ],
            ),
          ),
        ],
      ),
    );
  }

}

class _InfoChip extends StatelessWidget {
    final IconData icon;
    final String label;
    final Color color;
    final VoidCallback? onDeleted; // NEW

    const _InfoChip({required this.icon, required this.label, required this.color, this.onDeleted});

    @override
    Widget build(BuildContext context) {
        return GestureDetector(
            onTap: onDeleted,
            child: Container(
                margin: const EdgeInsets.only(right: 8, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Icon(icon, size: 14, color: color),
                        const SizedBox(width: 4),
                        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                        if (onDeleted != null) ...[
                             const SizedBox(width: 4),
                             Icon(Icons.close, size: 12, color: color.withOpacity(0.7)),
                        ]
                    ],
                ),
            ),
        );
    }
}
