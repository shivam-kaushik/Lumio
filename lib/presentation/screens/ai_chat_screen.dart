import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/ai_conversation_service.dart';
import '../../core/models/conversation_models.dart';
import '../../data/models/reminder.dart';
import '../../presentation/providers/reminder_provider.dart';
import '../../presentation/screens/goal_roadmap_screen.dart'; // MVP
import '../../presentation/theme/app_theme.dart';

/// AI Chat Screen - Conversational reminder creation
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  late AiConversationService _conversationService;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;
  bool _isListening = false;
  ConversationState _currentState = ConversationState.idle;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    _conversationService = AiConversationService();

    // Set up callbacks
    _conversationService.onReminderReady = (Reminder reminder) async {
      // Create reminder via provider
      final provider = context.read<ReminderProvider>();
      final id = await provider.createReminder(reminder);

      if (mounted && id != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder created successfully! ✅'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Optionally close the screen or reset
        Navigator.of(context).pop(reminder);
      }
    };

    // MVP: Handle goal roadmap ready
    _conversationService.onGoalRoadmapReady = (Map<String, dynamic> roadmapData) async {
      if (mounted) {
        // Navigate to goal roadmap screen
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GoalRoadmapScreen(roadmapData: roadmapData),
          ),
        );
        
        if (result == true && mounted) {
          // Goal was created successfully
          Navigator.of(context).pop();
        }
      }
    };

    _conversationService.onError = (String error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    };

    _conversationService.onStateChanged = (ConversationState state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
      }
    };

    final initialized = await _conversationService.initialize();
    if (mounted) {
      setState(() {
        _isInitialized = initialized;
      });

      if (initialized) {
        // Start conversation
        await _conversationService.startConversation(useVoice: false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    await _conversationService.processUserInput(text);
    _scrollToBottom();
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _conversationService.stopVoiceInput();
      setState(() {
        _isListening = false;
      });
    } else {
      await _conversationService.startVoiceInput();
      setState(() {
        _isListening = true;
      });
    }
  }

  @override
  void dispose() {
    _conversationService.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'AI Assistant',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_currentState == ConversationState.confirming)
            TextButton(
              onPressed: () async {
                // Confirm via message input
                await _conversationService.processUserInput('yes');
              },
              child: const Text(
                'Confirm',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
        ],
      ),
      body: !_isInitialized
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: StreamBuilder<ConversationMessage>(
                    stream: _conversationService.messageStream,
                    builder: (context, snapshot) {
                      final messages = _conversationService.messages;

                      if (messages.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppTheme.spacingMD),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return _buildMessageBubble(message);
                        },
                      );
                    },
                  ),
                ),

                // Input area
                Container(
                  padding: EdgeInsets.only(
                    left: AppTheme.spacingMD,
                    right: AppTheme.spacingMD,
                    top: AppTheme.spacingSM,
                    bottom: MediaQuery.of(context).padding.bottom +
                        AppTheme.spacingMD,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    border: Border(
                      top: BorderSide(
                        color: AppTheme.borderColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        // Voice input button
                        IconButton(
                          icon: Icon(
                            _isListening
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            color: _isListening
                                ? AppTheme.errorColor
                                : AppTheme.textSecondary,
                          ),
                          onPressed: _toggleVoiceInput,
                          tooltip: _isListening
                              ? 'Stop recording'
                              : 'Start voice input',
                        ),

                        // Text input
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              hintStyle: TextStyle(
                                color: AppTheme.textTertiary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusRound,
                                ),
                                borderSide: BorderSide(
                                  color: AppTheme.borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusRound,
                                ),
                                borderSide: BorderSide(
                                  color: AppTheme.borderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusRound,
                                ),
                                borderSide: BorderSide(
                                  color: AppTheme.primaryColor,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingMD,
                                vertical: AppTheme.spacingMD,
                              ),
                              filled: true,
                              fillColor: AppTheme.backgroundColor,
                            ),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),

                        const SizedBox(width: AppTheme.spacingSM),

                        // Send button
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                            ),
                            onPressed: _sendMessage,
                            tooltip: 'Send message',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(ConversationMessage message) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // AI avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 20,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
          ],

          // Message bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
                vertical: AppTheme.spacingSM + 4,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.primaryColor
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppTheme.radiusMD),
                  topRight: const Radius.circular(AppTheme.radiusMD),
                  bottomLeft: Radius.circular(
                    isUser ? AppTheme.radiusMD : 0,
                  ),
                  bottomRight: Radius.circular(
                    isUser ? 0 : AppTheme.radiusMD,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.shadowColor,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : AppTheme.textPrimary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),

          if (isUser) ...[
            const SizedBox(width: AppTheme.spacingSM),
            // User avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 20,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
