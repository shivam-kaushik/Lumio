import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/chat_controller.dart';
import '../models/chat_message.dart';
import '../theme/theme.dart';
import '../../core/services/premium_service.dart';
import 'premium_subscription_screen.dart';
import '../providers/growth_provider.dart';
import '../../data/models/goal_task.dart';
import 'goals_screen.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatController()..initialize(openFreshChat: true),
      child: const _ChatScreenContent(),
    );
  }
}

class _ChatScreenContent extends StatefulWidget {
  const _ChatScreenContent();

  @override
  State<_ChatScreenContent> createState() => _ChatScreenContentState();
}

class _ChatScreenContentState extends State<_ChatScreenContent> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final Set<String> _actionPersistInProgress = <String>{};
  bool? _isPremium;

  final List<Map<String, dynamic>> _quickActions = [
    {'icon': Icons.list_alt, 'label': 'Outline modules'},
    {'icon': Icons.person_search, 'label': 'Define persona'},
    {'icon': Icons.lightbulb_outline, 'label': 'Brainstorm'},
    {'icon': Icons.schedule, 'label': 'Plan schedule'},
  ];

  @override
  void initState() {
    super.initState();
    _checkPremium();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkPremium() async {
    final isPremium = await PremiumService().isPremium();
    if (mounted) setState(() => _isPremium = isPremium);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showConversationSelector(ChatController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildConversationSheet(controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF201A12) : const Color(0xFFF8F7F6);
    final surfaceColor = isDark ? const Color(0xFF2D261E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A150F);
    final subtleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final aiMessageBg = isDark ? const Color(0xFF2D261E) : const Color(0xFFF2EEE9);
    final userMessageBg = isDark ? LumioColors.primary : const Color(0xFF1A150F);
    final dividerColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _executePendingActions(controller.messages);

    if (_isPremium == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isPremium!) {
      return _buildPremiumGate(context, isDark, backgroundColor, textColor, subtleColor);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, controller, isDark, textColor, subtleColor, surfaceColor, dividerColor),

            // Chat List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: 1 + controller.messages.length + (controller.state == ChatState.processing ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Date header
                    return _buildDateHeader(isDark);
                  }
                  final messageIndex = index - 1;
                  if (messageIndex == controller.messages.length) {
                    return _buildThinkingIndicator(isDark, aiMessageBg, subtleColor);
                  }
                  return _buildMessage(
                    context,
                    controller.messages[messageIndex],
                    isDark,
                    textColor,
                    aiMessageBg,
                    userMessageBg,
                    surfaceColor,
                  );
                },
              ),
            ),

            // Input Area
            _buildInputArea(
              context,
              controller,
              isDark,
              textColor,
              subtleColor,
              surfaceColor,
              dividerColor,
            ),
          ],
        ),
      ),
    );
  }

  void _executePendingActions(List<ChatMessage> messages) {
    final pendingActions = messages
        .where((m) => m.isAction && !context.read<ChatController>().isActionExecuted(m.id))
        .where((m) => !_actionPersistInProgress.contains(m.id))
        .toList();
    if (pendingActions.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<ChatController>();
      for (final msg in pendingActions) {
        if (!mounted) return;
        _actionPersistInProgress.add(msg.id);
        final success = await _persistActionMessage(msg);
        _actionPersistInProgress.remove(msg.id);
        if (success) {
          await controller.markActionExecuted(msg.id);
        }
      }
    });
  }

  Future<bool> _persistActionMessage(ChatMessage msg) async {
    final actionType = (msg.actionType ?? '').toUpperCase();
    final growth = context.read<GrowthProvider>();
    final actionData = msg.actionData ?? <String, dynamic>{};

    try {
      if (actionType.contains('TASK')) {
        await _createTaskFromAction(growth, actionData);
        return true;
      } else if (actionType.contains('GOAL')) {
        await _createGoalFromAction(growth, actionData);
        return true;
      }
      return false;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save AI action: $e')),
      );
      return false;
    }
  }

  Future<void> _createTaskFromAction(
    GrowthProvider growth,
    Map<String, dynamic> actionData,
  ) async {
    final taskTitle = _deriveTaskTitleFromContext(actionData);
    if (taskTitle.isEmpty) return;

    final goalId = await _ensureInboxGoalId(growth);
    final scheduledDate = _deriveTaskScheduledDate(actionData);
    final task = GoalTask(
      id: 0,
      goalId: goalId,
      title: taskTitle,
      description: (actionData['description'] ?? '').toString(),
      createdAt: DateTime.now(),
      scheduledDate: scheduledDate,
      priority: _normalizePriority(actionData['priority']),
      frequency: _normalizeFrequency(actionData['frequency']),
      isCompleted: false,
      estimatedHours: 0.5,
      order: 0,
      indentLevel: 0,
      subtasks: [],
    );

    await growth.createTask(task);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Task added: '$taskTitle'")),
    );
  }

  Future<void> _createGoalFromAction(
    GrowthProvider growth,
    Map<String, dynamic> actionData,
  ) async {
    final goalName = _deriveGoalNameFromContext(actionData);
    if (goalName.isEmpty) return;

    DateTime? targetDeadline;
    final deadlineRaw = actionData['deadline']?.toString();
    if (deadlineRaw != null && deadlineRaw.isNotEmpty) {
      targetDeadline = DateTime.tryParse(deadlineRaw);
    }

    final goalId = await growth.createGoal(
      goalName,
      targetDeadline: targetDeadline,
    );

    final tasksData = actionData['tasks'];
    if (tasksData is List) {
      for (final taskItem in tasksData) {
        if (taskItem is! Map) continue;
        final map = Map<String, dynamic>.from(taskItem);
        final title = (map['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;

        await growth.createTask(
          GoalTask(
            id: 0,
            goalId: goalId,
            title: title,
            description: (map['description'] ?? '').toString(),
            createdAt: DateTime.now(),
            priority: _normalizePriority(map['priority']),
            frequency: _normalizeFrequency(map['frequency']),
            isCompleted: false,
            estimatedHours: 1.0,
            order: 0,
            indentLevel: 0,
            subtasks: [],
          ),
        );
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Goal created: '$goalName'")),
    );
  }

  String _deriveGoalNameFromContext(Map<String, dynamic> actionData) {
    final rawGoal = (actionData['goal'] ?? actionData['title'] ?? '').toString();
    final sanitizedRaw = _sanitizeGoalCandidate(rawGoal);
    if (_isMeaningfulGoalName(sanitizedRaw)) {
      return sanitizedRaw;
    }

    final chat = context.read<ChatController>();
    final userMessages = chat.messages
        .where((m) => m.sender == ChatSender.user)
        .map((m) => m.text)
        .toList()
        .reversed
        .toList();

    for (final message in userMessages) {
      final candidate = _sanitizeGoalCandidate(message);
      if (_isMeaningfulGoalName(candidate)) {
        return candidate;
      }
    }

    return 'New Goal';
  }

  String _sanitizeGoalCandidate(String input) {
    if (input.trim().isEmpty) return '';
    var text = input.trim();

    // Remove common AI confirmation boilerplate when it leaks into title field.
    final boilerplatePatterns = <RegExp>[
      RegExp(r"^i[' ]?ve\s+created\s+your\s+goal\s+", caseSensitive: false),
      RegExp(r'^great!\s*', caseSensitive: false),
      RegExp(r'^create\s+(a\s+)?goal(\s+to)?\s+', caseSensitive: false),
      RegExp(r'^set\s+(a\s+)?goal(\s+to)?\s+', caseSensitive: false),
      RegExp(r'^i\s+want\s+to\s+', caseSensitive: false),
      RegExp(r'^goal\s*(name|title)?\s*[:\-]\s*', caseSensitive: false),
    ];
    for (final p in boilerplatePatterns) {
      text = text.replaceFirst(p, '');
    }

    // Trim trailing AI-like sentence fragments.
    text = text
        .replaceAll(RegExp(r"let'?s\s+do\s+this!?\.?", caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+with\s+a\s+deadline.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+in\s+\d+\s+(day|days|week|weeks|month|months|year|years).*$',
            caseSensitive: false), '')
        .trim();

    // Basic spelling cleanup for common goal words.
    const corrections = <String, String>{
      'buisness': 'business',
      'busines': 'business',
      'bussiness': 'business',
      'acheive': 'achieve',
      'achive': 'achieve',
      'sucess': 'success',
      'succes': 'success',
    };

    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) {
      final lower = w.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      if (corrections.containsKey(lower)) {
        return corrections[lower]!;
      }
      return w;
    }).toList();

    text = words.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    // Title case for display consistency.
    final smallWords = {'a', 'an', 'and', 'or', 'to', 'of', 'the', 'for', 'in', 'on'};
    final titled = text.split(' ').asMap().entries.map((entry) {
      final i = entry.key;
      final word = entry.value;
      if (word.isEmpty) return word;
      final lw = word.toLowerCase();
      if (i > 0 && smallWords.contains(lw)) return lw;
      return '${lw[0].toUpperCase()}${lw.substring(1)}';
    }).join(' ');

    return titled.trim();
  }

  bool _isMeaningfulGoalName(String name) {
    final value = name.trim();
    if (value.length < 4) return false;

    final lower = value.toLowerCase();
    final invalidFragments = [
      'created your goal',
      'great!',
      'let\'s do this',
      'new goal',
      'goal created',
      'i want to achieve this goal',
    ];
    if (invalidFragments.any(lower.contains)) return false;
    return true;
  }

  Future<int> _ensureInboxGoalId(GrowthProvider growth) async {
    if (growth.goals.isEmpty) {
      await growth.loadGrowthData();
    }

    for (final goal in growth.goals) {
      if (goal.name == 'Inbox') return goal.id;
    }

    return growth.createGoal('Inbox');
  }

  String _normalizePriority(dynamic value) {
    final priority = value?.toString().toLowerCase() ?? 'medium';
    if (priority == 'high' || priority == 'low') return priority;
    return 'medium';
  }

  String _normalizeFrequency(dynamic value) {
    final frequency = value?.toString().toLowerCase() ?? 'one-time';
    if (frequency == 'daily' || frequency == 'weekly' || frequency == 'monthly') {
      return frequency;
    }
    return 'one-time';
  }

  String _deriveTaskTitleFromContext(Map<String, dynamic> actionData) {
    final raw = (actionData['title'] ?? actionData['task'] ?? '').toString();
    final cleanedRaw = _sanitizeTaskCandidate(raw);
    if (_isMeaningfulTaskName(cleanedRaw)) return cleanedRaw;

    final chat = context.read<ChatController>();
    final userMessages = chat.messages
        .where((m) => m.sender == ChatSender.user)
        .map((m) => m.text)
        .toList()
        .reversed
        .toList();

    for (final msg in userMessages) {
      final candidate = _sanitizeTaskCandidate(msg);
      if (_isMeaningfulTaskName(candidate)) return candidate;
    }

    return 'New Task';
  }

  String _sanitizeTaskCandidate(String input) {
    if (input.trim().isEmpty) return '';
    var text = input.trim();

    final boilerplatePatterns = <RegExp>[
      RegExp(r"^i[' ]?ve\s+added\s+", caseSensitive: false),
      RegExp(r'^added\s+', caseSensitive: false),
      RegExp(r'^task\s+created[:\-]?\s*', caseSensitive: false),
      RegExp(r'^create\s+(a\s+)?task(\s+for\s+today)?\s*(to)?\s*', caseSensitive: false),
      RegExp(r'^add\s+(a\s+)?task(\s+for\s+today)?\s*(to)?\s*', caseSensitive: false),
      RegExp(r'^remind me to\s+', caseSensitive: false),
      RegExp(r'^i\s+need\s+to\s+', caseSensitive: false),
    ];
    for (final p in boilerplatePatterns) {
      text = text.replaceFirst(p, '');
    }

    text = text
        .replaceAll(RegExp(r'\bat\s+\d{1,2}([:.]\d{2})?\s*(a\.?m\.?|p\.?m\.?)?\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(today|tomorrow|tonight)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r"let'?s\s+do\s+this!?\.?", caseSensitive: false), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const corrections = <String, String>{
      'buisness': 'business',
      'recieve': 'receive',
      'acheive': 'achieve',
      'sucess': 'success',
      'pary': 'party',
      'partyy': 'party',
      'tommorow': 'tomorrow',
    };

    final words = text.split(' ').where((w) => w.isNotEmpty).map((w) {
      final lw = w.toLowerCase();
      return corrections[lw] ?? lw;
    }).toList();

    final smallWords = {'a', 'an', 'and', 'or', 'to', 'of', 'the', 'for', 'in', 'on'};
    return words.asMap().entries.map((entry) {
      final i = entry.key;
      final word = entry.value;
      if (i > 0 && smallWords.contains(word)) return word;
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
  }

  bool _isMeaningfulTaskName(String name) {
    final value = name.trim().toLowerCase();
    if (value.length < 3) return false;
    const bad = {'ve added', 'added', 'task created', 'new task', 'create a task'};
    if (bad.contains(value)) return false;
    return true;
  }

  DateTime? _deriveTaskScheduledDate(Map<String, dynamic> actionData) {
    final explicit = actionData['scheduledDate']?.toString();
    if (explicit != null && explicit.isNotEmpty) {
      final parsed = DateTime.tryParse(explicit);
      if (parsed != null) return parsed;
    }

    final chat = context.read<ChatController>();
    final lastUserText = chat.messages
        .where((m) => m.sender == ChatSender.user)
        .map((m) => m.text)
        .toList()
        .reversed
        .cast<String?>()
        .firstWhere((m) => m != null && m.trim().isNotEmpty, orElse: () => null);

    if (lastUserText == null) return null;
    final lower = lastUserText.toLowerCase();
    var baseDate = DateTime.now();
    if (lower.contains('tomorrow')) {
      baseDate = baseDate.add(const Duration(days: 1));
    }

    final timeMatch = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)\b',
      caseSensitive: false,
    ).firstMatch(lower);

    if (timeMatch != null) {
      var hour = int.tryParse(timeMatch.group(1) ?? '0') ?? 0;
      final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      final period = (timeMatch.group(3) ?? '').toLowerCase();
      final isPm = period.contains('p');
      if (isPm && hour < 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    }

    if (lower.contains('today') || lower.contains('tomorrow') || lower.contains('tonight')) {
      return DateTime(baseDate.year, baseDate.month, baseDate.day, 18, 0);
    }

    return null;
  }

  Widget _buildHeader(
    BuildContext context,
    ChatController controller,
    bool isDark,
    Color textColor,
    Color subtleColor,
    Color surfaceColor,
    Color dividerColor,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          // Back Button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, color: textColor),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
            ),
          ),

          // Center Title
          Expanded(
            child: Column(
              children: [
                Text(
                  "COACH",
                  style: TextStyle(
                    color: LumioColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () => _showConversationSelector(controller),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          controller.activeConversationTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.expand_more,
                        color: subtleColor,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // More Options
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.more_vert, color: textColor),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "Today, ${TimeOfDay.now().format(context)}",
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(
    BuildContext context,
    ChatMessage msg,
    bool isDark,
    Color textColor,
    Color aiMessageBg,
    Color userMessageBg,
    Color surfaceColor,
  ) {
    final isUser = msg.sender == ChatSender.user;

    if (msg.isAction) {
      return _buildActionCard(context, msg, isDark, textColor, surfaceColor);
    }

    if (isUser) {
      return _buildUserMessage(msg, isDark, userMessageBg);
    } else {
      return _buildAIMessage(msg, isDark, textColor, aiMessageBg);
    }
  }

  Widget _buildAIMessage(ChatMessage msg, bool isDark, Color textColor, Color aiMessageBg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? const Color(0xFF2D261E) : Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  LumioColors.primary.withOpacity(0.8),
                  LumioColors.primary,
                ],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Message Content
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    "Lumio",
                    style: TextStyle(
                      color: LumioColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: aiMessageBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.05, end: 0);
  }

  Widget _buildUserMessage(ChatMessage msg, bool isDark, Color userMessageBg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: userMessageBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isDark ? const Color(0xFF1A150F) : Colors.white,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildActionCard(
    BuildContext context,
    ChatMessage msg,
    bool isDark,
    Color textColor,
    Color surfaceColor,
  ) {
    if (msg.actionType == 'CREATE_TASK') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Task Created",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      msg.actionData?['title'] ?? 'New Task',
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn().slideX(),
      );
    }

    // CREATE_GOAL
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const GoalsScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border.all(color: LumioColors.primary.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: LumioColors.primary.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: LumioColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.rocket_launch,
                      color: LumioColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      msg.actionData?['goal'] ?? 'New Goal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                msg.text,
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: LumioColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      color: LumioColors.primary,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'View in Goals',
                      style: TextStyle(
                        color: LumioColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95), duration: 400.ms);
  }

  Widget _buildThinkingIndicator(bool isDark, Color aiMessageBg, Color subtleColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  LumioColors.primary.withOpacity(0.8),
                  LumioColors.primary,
                ],
              ),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: aiMessageBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildTypingDot(int index) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: LumioColors.primary.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 0.6,
          end: 1.0,
          duration: 400.ms,
          delay: (index * 150).ms,
          curve: Curves.easeInOut,
        )
        .fadeIn(begin: 0.4);
  }

  Widget _buildInputArea(
    BuildContext context,
    ChatController controller,
    bool isDark,
    Color textColor,
    Color subtleColor,
    Color surfaceColor,
    Color dividerColor,
  ) {
    if (controller.state == ChatState.listening) {
      return _buildLiveOverlay(context, controller, isDark);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          // Quick Actions
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickActions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final action = _quickActions[index];
                return Material(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    onTap: () {
                      controller.sendTextMessage(action['label']);
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: LumioColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            action['icon'],
                            size: 18,
                            color: LumioColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            action['label'],
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Input Row
          Row(
            children: [
              // Input Field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: dividerColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Add Button
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.add, color: subtleColor),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                        ),
                      ),

                      // Text Field
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          style: TextStyle(color: textColor, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: "Message Lumio...",
                            hintStyle: TextStyle(color: subtleColor.withOpacity(0.6)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (val) {
                            if (val.isNotEmpty) {
                              controller.sendTextMessage(val);
                              _textController.clear();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Mic/Send Button
              GestureDetector(
                onTap: () {
                  if (_textController.text.isNotEmpty) {
                    controller.sendTextMessage(_textController.text);
                    _textController.clear();
                  } else {
                    controller.startListening();
                  }
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: LumioColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: LumioColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _textController.text.isNotEmpty ? Icons.send : Icons.mic,
                    color: const Color(0xFF1A150F),
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveOverlay(BuildContext context, ChatController controller, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LumioColors.primary,
            LumioColors.primary.withOpacity(0.9),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Waveform Animation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                7,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleY(
                      begin: 0.2,
                      end: 1.0,
                      duration: 300.ms + (index * 80).ms,
                      curve: Curves.easeInOut,
                    ),
              ),
            ),
            const SizedBox(height: 20),

            // Live Text
            Text(
              controller.currentTranscript.isEmpty
                  ? "Listening..."
                  : controller.currentTranscript,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Stop Button
            GestureDetector(
              onTap: () => controller.stopListening(),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.stop,
                  color: LumioColors.primary,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }

  Widget _buildConversationSheet(ChatController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF2D261E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A150F);
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Conversation History',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                onTap: () async {
                  await controller.startNewConversation();
                  if (mounted) Navigator.pop(context);
                },
                leading: const Icon(Icons.add_comment_rounded, color: LumioColors.primary),
                title: const Text('New conversation'),
                subtitle: const Text('Start fresh with Lumio'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  itemCount: controller.savedConversations.length,
                  itemBuilder: (context, index) {
                    final conversation = controller.savedConversations[index];
                    final conversationId = (conversation['id'] ?? '').toString();
                    final title = (conversation['title'] ?? 'New Conversation').toString();
                    final updatedAtRaw = (conversation['updatedAt'] ?? '').toString();
                    final updatedAt = DateTime.tryParse(updatedAtRaw);
                    final subtitle = updatedAt == null
                        ? 'Saved chat'
                        : 'Updated ${updatedAt.toLocal().toString().split('.').first}';
                    final isSelected = conversationId == controller.activeConversationId;
                    return ListTile(
                      onTap: () async {
                        await controller.loadConversation(conversationId);
                        if (!mounted) return;
                        Navigator.of(this.context).pop();
                      },
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? LumioColors.primary : Colors.grey,
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(subtitle),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.redAccent,
                        tooltip: 'Delete chat',
                        onPressed: () async {
                          final shouldDelete = await showDialog<bool>(
                                context: this.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Delete Chat'),
                                  content: Text('Delete "$title"? This cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.redAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;

                          if (!shouldDelete) return;
                          await controller.deleteConversation(conversationId);
                        },
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumGate(
    BuildContext context,
    bool isDark,
    Color backgroundColor,
    Color textColor,
    Color subtleColor,
  ) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: LumioColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: LumioColors.primary.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock, size: 32, color: Colors.orange),
              ),
              const SizedBox(height: 20),
              Text(
                "Premium Feature",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Upgrade to unlock the AI Coach and get personalized goal coaching.",
                textAlign: TextAlign.center,
                style: TextStyle(color: subtleColor, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    await openPremiumPaywall(context);
                    if (mounted) _checkPremium();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LumioColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: LumioColors.primary.withOpacity(0.4),
                  ),
                  child: const Text(
                    "Upgrade to Premium",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
