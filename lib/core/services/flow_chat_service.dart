import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart';
import '../../presentation/providers/growth_provider.dart';

// ---------------------------------------------------------------------------
// Enums & Models
// ---------------------------------------------------------------------------

enum FlowIntent { createGoal, createTask, createSubtask, listTasks, unknown }

/// A single message in the flow chat.
class FlowMessage {
  final String id;
  final String text;
  final bool isUser;
  final bool isSuccess;
  final bool isError;
  final String? successType; // 'goal' | 'task' | 'subtask'
  final Map<String, dynamic>? successData;
  final DateTime timestamp;

  FlowMessage._({
    required this.id,
    required this.text,
    required this.isUser,
    this.isSuccess = false,
    this.isError = false,
    this.successType,
    this.successData,
    required this.timestamp,
  });

  factory FlowMessage.bot(String text) => FlowMessage._(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      );

  factory FlowMessage.user(String text) => FlowMessage._(
        id: '${DateTime.now().microsecondsSinceEpoch}u',
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      );

  factory FlowMessage.success(
    String text, {
    String? type,
    Map<String, dynamic>? data,
  }) =>
      FlowMessage._(
        id: '${DateTime.now().microsecondsSinceEpoch}s',
        text: text,
        isUser: false,
        isSuccess: true,
        successType: type,
        successData: data,
        timestamp: DateTime.now(),
      );

  factory FlowMessage.error(String text) => FlowMessage._(
        id: '${DateTime.now().microsecondsSinceEpoch}e',
        text: text,
        isUser: false,
        isError: true,
        timestamp: DateTime.now(),
      );
}

/// Definition of one step in a conversational flow.
class _FlowStep {
  final String field;
  final String question;
  final bool optional;

  const _FlowStep({
    required this.field,
    required this.question,
    required this.optional,
  });
}

/// In-memory session that tracks the current flow.
class _FlowSession {
  final FlowIntent intent;
  int currentStepIndex = 0;
  Map<String, dynamic> collectedData = {};
  bool isConfirming = false;

  _FlowSession({required this.intent});
}

// ---------------------------------------------------------------------------
// FlowChatService — ChangeNotifier
// ---------------------------------------------------------------------------

/// Manages the conversational state for goal/task/subtask creation.
///
/// Intent detection uses keyword matching first (zero-latency) and falls back
/// to the OpenAI API for ambiguous inputs. Step-by-step data collection,
/// skip/cancel support, and a confirmation step are all handled here.
class FlowChatService extends ChangeNotifier {
  final GrowthProvider _growthProvider;

  FlowChatService(this._growthProvider) {
    _greet();
  }

  // ---- state ----
  final List<FlowMessage> _messages = [];
  _FlowSession? _session;
  bool _isLoading = false;

  List<FlowMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;

  // ---------------------------------------------------------------------------
  // Flow step definitions
  // ---------------------------------------------------------------------------

  static const Map<FlowIntent, List<_FlowStep>> _flowSteps = {
    FlowIntent.createGoal: [
      _FlowStep(
        field: 'goalName',
        question: 'What would you like to name this goal?',
        optional: false,
      ),
      _FlowStep(
        field: 'deadline',
        question:
            "When do you want to achieve this? (e.g. 'Dec 31', 'next month') — or type skip",
        optional: true,
      ),
      _FlowStep(
        field: 'priority',
        question: 'Priority? Reply high, medium, or low — or skip',
        optional: true,
      ),
    ],
    FlowIntent.createTask: [
      _FlowStep(
        field: 'taskName',
        question: "What's the task name?",
        optional: false,
      ),
      _FlowStep(
        field: 'dueDate',
        question:
            "When is it due? (e.g. 'tomorrow', 'Friday') — or type skip",
        optional: true,
      ),
      _FlowStep(
        field: 'goalName',
        question:
            'Which goal is this for? (type the goal name) — or skip to add to Inbox',
        optional: true,
      ),
    ],
    FlowIntent.createSubtask: [
      _FlowStep(
        field: 'parentTaskName',
        question: "What's the name of the parent task?",
        optional: false,
      ),
      _FlowStep(
        field: 'subtaskName',
        question: 'What should the subtask be called?',
        optional: false,
      ),
      _FlowStep(
        field: 'dueDate',
        question: 'Due date for the subtask? — or type skip',
        optional: true,
      ),
    ],
  };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Entry point for every user message.
  Future<void> handleUserMessage(String text) async {
    final input = text.trim();
    if (input.isEmpty) return;

    _addUserMessage(input);

    // Global cancel/reset
    if (_isCancelInput(input)) {
      _cancelFlow();
      return;
    }

    if (_session == null) {
      await _detectAndStartFlow(input);
    } else if (_session!.isConfirming) {
      await _handleConfirmation(input);
    } else {
      _collectStepData(input);
    }
  }

  // ---------------------------------------------------------------------------
  // Intent detection & flow startup
  // ---------------------------------------------------------------------------

  Future<void> _detectAndStartFlow(String raw) async {
    _setLoading(true);

    FlowIntent intent = _detectIntentLocally(raw);

    if (intent == FlowIntent.unknown) {
      // Fallback: ask OpenAI to classify
      intent = await _detectIntentWithAI(raw);
    }

    _setLoading(false);
    _startFlow(intent, rawInput: raw);
  }

  void _startFlow(FlowIntent intent, {String? rawInput}) {
    if (intent == FlowIntent.unknown) {
      _addBotMessage(
        'I can help you create goals, tasks, or subtasks — or list your tasks. What would you like to do?',
      );
      return;
    }

    if (intent == FlowIntent.listTasks) {
      _handleListTasks();
      return;
    }

    _session = _FlowSession(intent: intent);

    // Try to pre-fill the name field from the user's opening message
    if (rawInput != null) {
      _tryPrefillName(rawInput, intent);
    }

    _askCurrentStep();
  }

  /// Attempts to extract a name directly from the user's opening message.
  void _tryPrefillName(String input, FlowIntent intent) {
    String? extracted;
    if (intent == FlowIntent.createGoal) {
      extracted = _extractAfterKeyword(
        input,
        ['create goal', 'add goal', 'new goal', 'set goal', 'goal'],
      );
      if (extracted != null) {
        _session!.collectedData['goalName'] = extracted;
        _session!.currentStepIndex = 1; // jump past name step
      }
    } else if (intent == FlowIntent.createTask) {
      extracted = _extractAfterKeyword(
        input,
        ['create task', 'add task', 'new task', 'todo', 'remind me to', 'task'],
      );
      if (extracted != null) {
        _session!.collectedData['taskName'] = extracted;
        _session!.currentStepIndex = 1;
      }
    }
  }

  String? _extractAfterKeyword(String input, List<String> keywords) {
    final lower = input.toLowerCase();
    for (final kw in keywords) {
      final idx = lower.indexOf(kw);
      if (idx != -1) {
        final after = input.substring(idx + kw.length).trim();
        if (after.length > 1) return after;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Step-by-step data collection
  // ---------------------------------------------------------------------------

  void _askCurrentStep() {
    if (_session == null) return;
    final steps = _flowSteps[_session!.intent];
    if (steps == null || _session!.currentStepIndex >= steps.length) {
      _showConfirmation();
      return;
    }
    _addBotMessage(steps[_session!.currentStepIndex].question);
  }

  void _collectStepData(String input) {
    if (_session == null) return;
    final steps = _flowSteps[_session!.intent] ?? [];
    if (_session!.currentStepIndex >= steps.length) return;

    final step = steps[_session!.currentStepIndex];
    final isSkip = _isSkipInput(input);

    if (isSkip) {
      if (!step.optional) {
        _addBotMessage(
          'This field is required — please provide a value.\n${step.question}',
        );
        return;
      }
      // Leave field absent to signal "not provided"
    } else {
      _session!.collectedData[step.field] = input;
    }

    _session!.currentStepIndex++;

    if (_session!.currentStepIndex < steps.length) {
      _askCurrentStep();
    } else {
      _showConfirmation();
    }
  }

  // ---------------------------------------------------------------------------
  // Confirmation
  // ---------------------------------------------------------------------------

  void _showConfirmation() {
    if (_session == null) return;
    _session!.isConfirming = true;
    final summary = _buildSummary(_session!.intent, _session!.collectedData);
    _addBotMessage(
      "Here's what I'll create:\n\n$summary\n\nType yes to confirm or no to cancel.",
    );
  }

  String _buildSummary(FlowIntent intent, Map<String, dynamic> data) {
    switch (intent) {
      case FlowIntent.createGoal:
        final name = data['goalName'] ?? 'Unnamed goal';
        final dl =
            data['deadline'] != null ? '\nDeadline: ${data['deadline']}' : '';
        final pr =
            data['priority'] != null ? '\nPriority: ${data['priority']}' : '';
        return 'Goal: $name$dl$pr';

      case FlowIntent.createTask:
        final name = data['taskName'] ?? 'Unnamed task';
        final due =
            data['dueDate'] != null ? '\nDue: ${data['dueDate']}' : '';
        final goal = data['goalName'] != null
            ? '\nGoal: ${data['goalName']}'
            : '\nGoal: Inbox';
        return 'Task: $name$due$goal';

      case FlowIntent.createSubtask:
        final parent = data['parentTaskName'] ?? '?';
        final sub = data['subtaskName'] ?? 'Unnamed subtask';
        final due =
            data['dueDate'] != null ? '\nDue: ${data['dueDate']}' : '';
        return 'Subtask: $sub\nUnder: $parent$due';

      default:
        return data.toString();
    }
  }

  Future<void> _handleConfirmation(String input) async {
    final lower = input.toLowerCase();
    if (lower == 'yes' ||
        lower == 'y' ||
        lower == 'confirm' ||
        lower == 'ok') {
      await _executeFlow();
    } else if (lower == 'no' || lower == 'n') {
      _cancelFlow();
    } else {
      _addBotMessage('Please type yes to confirm or no to cancel.');
    }
  }

  // ---------------------------------------------------------------------------
  // Flow execution — calls GrowthProvider
  // ---------------------------------------------------------------------------

  Future<void> _executeFlow() async {
    if (_session == null) return;
    _setLoading(true);

    try {
      switch (_session!.intent) {
        case FlowIntent.createGoal:
          await _executeCreateGoal();
          break;
        case FlowIntent.createTask:
          await _executeCreateTask();
          break;
        case FlowIntent.createSubtask:
          await _executeCreateSubtask();
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('FlowChatService execute error: $e');
      _addErrorMessage(
        'Something went wrong: ${e.toString()}\nWould you like to try again?',
      );
    } finally {
      _setLoading(false);
      _session = null;
    }
  }

  Future<void> _executeCreateGoal() async {
    final data = _session!.collectedData;
    final name = data['goalName'] as String;
    final deadline = _parseDate(data['deadline'] as String?);

    await _growthProvider.createGoal(name, targetDeadline: deadline);

    _addSuccessMessage(
      'Goal "$name" created!',
      type: 'goal',
      data: {'name': name},
    );
    _addBotMessage('What else can I help you with?');
  }

  Future<void> _executeCreateTask() async {
    final data = _session!.collectedData;
    final taskName = data['taskName'] as String;
    final goalName = data['goalName'] as String?;
    final dueDateStr = data['dueDate'] as String?;

    // Resolve goal id
    int goalId;
    if (goalName != null) {
      final match = _growthProvider.goals.firstWhere(
        (g) => g.name.toLowerCase().contains(goalName.toLowerCase()),
        orElse: () => Goal(id: -1, name: 'Inbox', createdAt: DateTime.now()),
      );
      goalId = match.id == -1 ? await _findOrCreateInbox() : match.id;
    } else {
      goalId = await _findOrCreateInbox();
    }

    final task = GoalTask(
      id: 0,
      goalId: goalId,
      title: taskName,
      description: '',
      createdAt: DateTime.now(),
      scheduledDate: _parseDate(dueDateStr),
      priority: 'medium',
      frequency: 'one-time',
      isCompleted: false,
      estimatedHours: 0.5,
      order: 0,
      indentLevel: 0,
      subtasks: const [],
    );

    await _growthProvider.createTask(task);

    _addSuccessMessage(
      'Task "$taskName" added!',
      type: 'task',
      data: {'name': taskName},
    );
    _addBotMessage('What else can I help you with?');
  }

  Future<void> _executeCreateSubtask() async {
    final data = _session!.collectedData;
    final parentName = data['parentTaskName'] as String;
    final subtaskName = data['subtaskName'] as String;
    final dueDateStr = data['dueDate'] as String?;

    // Find parent task (search all tasks across all goals)
    final allTasks = _growthProvider.allTasks;
    GoalTask? parent;
    try {
      parent = allTasks.firstWhere(
        (t) => t.title.toLowerCase().contains(parentName.toLowerCase()),
      );
    } catch (_) {}

    if (parent == null) {
      _addErrorMessage(
        'Could not find a task named "$parentName". Please make sure the task exists first.',
      );
      _session = null;
      return;
    }

    final subtask = GoalTask(
      id: 0,
      goalId: parent.goalId,
      title: subtaskName,
      description: '',
      createdAt: DateTime.now(),
      scheduledDate: _parseDate(dueDateStr),
      priority: 'medium',
      frequency: 'one-time',
      isCompleted: false,
      estimatedHours: 0.5,
      order: parent.subtasks.length,
      indentLevel: 1,
      subtasks: const [],
    );

    final updated = parent.copyWith(
      subtasks: [...parent.subtasks, subtask],
    );
    await _growthProvider.updateTask(updated);

    _addSuccessMessage(
      'Subtask "$subtaskName" added under "$parentName"!',
      type: 'subtask',
      data: {'name': subtaskName, 'parent': parentName},
    );
    _addBotMessage('What else can I help you with?');
  }

  // ---------------------------------------------------------------------------
  // List tasks
  // ---------------------------------------------------------------------------

  void _handleListTasks() {
    final tasks =
        _growthProvider.allTasks.where((t) => !t.isCompleted).toList();

    if (tasks.isEmpty) {
      _addBotMessage(
        'You have no pending tasks. Would you like to create one?',
      );
      return;
    }

    final lines = tasks.take(10).map((t) {
      final date = t.scheduledDate != null
          ? ' (${_formatDate(t.scheduledDate!)})'
          : '';
      return '• ${t.title}$date';
    }).join('\n');

    final more =
        tasks.length > 10 ? '\n...and ${tasks.length - 10} more' : '';
    _addBotMessage(
      'Your pending tasks:\n\n$lines$more\n\nWhat would you like to do?',
    );
  }

  // ---------------------------------------------------------------------------
  // Cancel
  // ---------------------------------------------------------------------------

  void _cancelFlow() {
    _session = null;
    _addBotMessage(
      "No problem! I'm here whenever you need me.\nI can help you create goals, tasks, or subtasks.",
    );
  }

  // ---------------------------------------------------------------------------
  // Intent Detection
  // ---------------------------------------------------------------------------

  FlowIntent _detectIntentLocally(String text) {
    final lower = text.toLowerCase();

    if (_hasAny(lower, [
      'list task',
      'show task',
      'my task',
      "what's due",
      'show me task',
      'display task',
      'list my',
    ])) {
      return FlowIntent.listTasks;
    }
    if (_hasAny(lower, ['subtask', 'sub-task', 'sub task', 'child task'])) {
      return FlowIntent.createSubtask;
    }
    if (_hasAny(
      lower,
      ['goal', 'create goal', 'add goal', 'new goal', 'set goal'],
    )) {
      return FlowIntent.createGoal;
    }
    if (_hasAny(lower, [
      'task',
      'add task',
      'create task',
      'new task',
      'todo',
      'to do',
      'to-do',
      'remind me',
    ])) {
      return FlowIntent.createTask;
    }
    return FlowIntent.unknown;
  }

  bool _hasAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  /// Calls OpenAI to classify ambiguous intent.
  Future<FlowIntent> _detectIntentWithAI(String text) async {
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null ||
          apiKey.isEmpty ||
          apiKey == 'your_openai_api_key_here') {
        return FlowIntent.unknown;
      }

      final res = await http
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': 'gpt-3.5-turbo',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are an intent classifier for a goal management app. '
                          'Classify the user message into exactly ONE of these labels: '
                          'CREATE_GOAL, CREATE_TASK, CREATE_SUBTASK, LIST_TASKS, UNKNOWN. '
                          'Reply with only the label.',
                },
                {'role': 'user', 'content': text},
              ],
              'temperature': 0,
              'max_tokens': 15,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final label =
            (jsonDecode(res.body)['choices'][0]['message']['content'] as String)
                .trim()
                .toUpperCase();
        switch (label) {
          case 'CREATE_GOAL':
            return FlowIntent.createGoal;
          case 'CREATE_TASK':
            return FlowIntent.createTask;
          case 'CREATE_SUBTASK':
            return FlowIntent.createSubtask;
          case 'LIST_TASKS':
            return FlowIntent.listTasks;
          default:
            return FlowIntent.unknown;
        }
      }
    } catch (e) {
      debugPrint('FlowChatService AI intent error: $e');
    }
    return FlowIntent.unknown;
  }

  // ---------------------------------------------------------------------------
  // Date parsing
  // ---------------------------------------------------------------------------

  DateTime? _parseDate(String? input) {
    if (input == null || input.isEmpty) return null;
    final lower = input.toLowerCase().trim();

    if (lower == 'today') return DateTime.now();
    if (lower == 'tomorrow') {
      return DateTime.now().add(const Duration(days: 1));
    }
    if (lower == 'next week') {
      return DateTime.now().add(const Duration(days: 7));
    }
    if (lower == 'next month') {
      final now = DateTime.now();
      return DateTime(now.year, now.month + 1, now.day);
    }

    // ISO format
    try {
      return DateTime.parse(input);
    } catch (_) {}

    // MM/DD/YYYY or DD-MM-YYYY
    final numericPattern = RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})');
    final numMatch = numericPattern.firstMatch(input);
    if (numMatch != null) {
      try {
        final a = int.parse(numMatch.group(1)!);
        final b = int.parse(numMatch.group(2)!);
        var year = int.parse(numMatch.group(3)!);
        if (year < 100) year += 2000;
        return DateTime(year, a, b);
      } catch (_) {}
    }

    // Month name + day (e.g. "Dec 31", "January 5")
    const monthMap = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    for (final entry in monthMap.entries) {
      if (lower.contains(entry.key)) {
        final dayMatch = RegExp(r'\d+').firstMatch(lower);
        if (dayMatch != null) {
          final day = int.parse(dayMatch.group(0)!);
          return DateTime(DateTime.now().year, entry.value, day);
        }
      }
    }

    return null;
  }

  String _formatDate(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${m[d.month - 1]} ${d.day}';
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<int> _findOrCreateInbox() async {
    try {
      return _growthProvider.goals.firstWhere((g) => g.name == 'Inbox').id;
    } catch (_) {
      return _growthProvider.createGoal('Inbox');
    }
  }

  void _greet() {
    _addBotMessage(
      'Hi! I\'m your goal assistant 👋\n\n'
      'I can help you:\n'
      '• Create a goal\n'
      '• Add a task\n'
      '• Add a subtask\n'
      '• List your tasks\n\n'
      'What would you like to do?',
    );
  }

  void _addBotMessage(String text) {
    _messages.add(FlowMessage.bot(text));
    notifyListeners();
  }

  void _addUserMessage(String text) {
    _messages.add(FlowMessage.user(text));
    notifyListeners();
  }

  void _addSuccessMessage(
    String text, {
    String? type,
    Map<String, dynamic>? data,
  }) {
    _messages.add(FlowMessage.success(text, type: type, data: data));
    notifyListeners();
  }

  void _addErrorMessage(String text) {
    _messages.add(FlowMessage.error(text));
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  bool _isCancelInput(String text) {
    final lower = text.toLowerCase();
    return lower == 'cancel' ||
        lower == 'quit' ||
        lower == 'exit' ||
        lower == 'reset' ||
        lower == 'start over';
  }

  bool _isSkipInput(String text) {
    final lower = text.toLowerCase();
    return lower == 'skip' || lower == 's' || lower == 'none' || lower == '-';
  }
}
