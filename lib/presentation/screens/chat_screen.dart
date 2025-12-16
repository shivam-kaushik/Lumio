import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/chat_controller.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import '../../core/services/premium_service.dart';
import 'unified_goal_editor_screen.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatController()..initialize(),
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
  bool? _isPremium;

  @override
  void initState() {
    super.initState();
    _checkPremium();
  }

  Future<void> _checkPremium() async {
    final isPremium = await PremiumService().isPremium();
    if (mounted) setState(() => _isPremium = isPremium);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    if (_isPremium == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isPremium!) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton()),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.psychology, size: 80, color: Colors.grey), // AI Icon
                const SizedBox(height: 24),
                const Icon(Icons.lock, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  "Premium Feature",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Upgrade to unlock the AI Assistant and get personalized goal coaching.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context), // TODO: Go to paywall
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text("Upgrade to Premium"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text("Lumio Assistant"),
        backgroundColor: AppTheme.surfaceColor,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Chat List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: controller.messages.length + (controller.state == ChatState.processing ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == controller.messages.length) {
                   return _buildThinkingIndicator();
                }
                return _buildMessage(context, controller.messages[index]);
              },
            ),
          ),

          // Input Area
          _buildInputArea(context, controller),
        ],
      ),
    );
  }

  Widget _buildMessage(BuildContext context, ChatMessage msg) {
    final isUser = msg.sender == ChatSender.user;
    
    if (msg.isAction) {
        return _buildActionCard(context, msg);
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4), // Tighter spacing
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            height: 1.4,
          ),
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildActionCard(BuildContext context, ChatMessage msg) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: InkWell(
              onTap: () {
                   Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => UnifiedGoalEditorScreen(aiResult: msg.actionData!),
                      ),
                   );
              },
              child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 0, offset: const Offset(0, 4)),
                      ],
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Row(children: [
                              const Icon(Icons.rocket_launch, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              Expanded(child: Text("Plan Ready: ${msg.actionData?['goal'] ?? 'New Goal'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          ]),
                          const SizedBox(height: 8),
                          Text(msg.text, style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 12),
                          Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text("Tap to Review Plan", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                          )
                      ],
                  ),
              ),
          ),
      ).animate().fadeIn().scale(duration: 400.ms);
  }

  Widget _buildThinkingIndicator() {
      return Align(
          alignment: Alignment.centerLeft,
          child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text("Assistant is thinking...", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
              ),
          ),
      ).animate().fadeIn();
  }

  Widget _buildInputArea(BuildContext context, ChatController controller) {
     return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
            child: Row(
                children: [
                    // Text Input
                    Expanded(
                        child: TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                                hintText: controller.state == ChatState.listening ? "Listening..." : "Type your goal...",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                                filled: true,
                                fillColor: Colors.grey[100],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            onSubmitted: (val) {
                                controller.sendTextMessage(val);
                                _textController.clear();
                            },
                        ),
                    ),
                    const SizedBox(width: 8),
                    // Send/Mic Button
                    GestureDetector( // Use GestureDetector to handle Hold-to-Talk if we wanted, but tap toggle is fine
                        onTap: () {
                            if (_textController.text.isNotEmpty) {
                                controller.sendTextMessage(_textController.text);
                                _textController.clear();
                            } else {
                                if (controller.state == ChatState.listening) {
                                    controller.stopListening();
                                } else {
                                    controller.startListening();
                                }
                            }
                        },
                        child: CircleAvatar(
                            radius: 24,
                            backgroundColor: controller.state == ChatState.listening ? Colors.redAccent : AppTheme.primaryColor,
                            child: Icon(
                                _textController.text.isNotEmpty ? Icons.send : (controller.state == ChatState.listening ? Icons.stop : Icons.mic),
                                color: Colors.white,
                            ),
                        ),
                    ).animate(target: controller.state == ChatState.listening ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1), duration: 200.ms),
                ],
            ),
        ),
     );
  }
}
