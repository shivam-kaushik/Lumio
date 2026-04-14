import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/services/flow_chat_service.dart';
import '../../../presentation/providers/growth_provider.dart';
import '../../../presentation/theme/theme.dart';
import 'flow_chat_message_bubble.dart';
import 'flow_chat_input.dart';

/// Floating chat button + slide-up panel for the flow-based goal assistant.
///
/// Drop this anywhere in a Stack (e.g. on the HomeScreen) — it manages its
/// own open/close state and creates a [FlowChatService] scoped to itself.
class FlowChatWidget extends StatefulWidget {
  const FlowChatWidget({super.key});

  @override
  State<FlowChatWidget> createState() => _FlowChatWidgetState();
}

class _FlowChatWidgetState extends State<FlowChatWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _panelController;
  late Animation<double> _panelAnimation;

  bool _isOpen = false;
  FlowChatService? _service;

  @override
  void initState() {
    super.initState();
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _panelAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _panelController.dispose();
    _service?.dispose();
    super.dispose();
  }

  void _togglePanel() {
    HapticFeedback.lightImpact();
    if (_isOpen) {
      _panelController.reverse().then((_) {
        if (mounted) setState(() => _isOpen = false);
      });
    } else {
      setState(() {
        _isOpen = true;
        // Create the service lazily so it picks up the latest GrowthProvider
        _service ??= FlowChatService(context.read<GrowthProvider>());
      });
      _panelController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ----- Chat panel -----
        if (_isOpen && _service != null)
          AnimatedBuilder(
            animation: _panelAnimation,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, (1 - _panelAnimation.value) * 30),
              child: Opacity(
                opacity: _panelAnimation.value,
                child: child,
              ),
            ),
            child: ChangeNotifierProvider<FlowChatService>.value(
              value: _service!,
              child: _ChatPanel(onClose: _togglePanel),
            ),
          ),

        // ----- FAB -----
        Align(
          alignment: Alignment.bottomRight,
          child: GestureDetector(
            onTap: _togglePanel,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isOpen ? Colors.grey[600] : LumioColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: LumioColors.primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isOpen ? Icons.close_rounded : Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          )
              .animate()
              .scale(
                  delay: 200.ms,
                  duration: 500.ms,
                  curve: Curves.elasticOut),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chat panel
// ---------------------------------------------------------------------------

class _ChatPanel extends StatefulWidget {
  final VoidCallback onClose;

  const _ChatPanel({required this.onClose});

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF201A12) : const Color(0xFFF8F7F6);
    final surfaceColor =
        isDark ? const Color(0xFF2D261E) : Colors.white;
    final textColor =
        isDark ? Colors.white : const Color(0xFF1A150F);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : LumioColors.border(context);

    final service = context.watch<FlowChatService>();

    // Auto-scroll on new messages
    _scrollToBottom();

    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        width: 320,
        height: 440,
        margin: const EdgeInsets.only(bottom: 64), // space above the FAB
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Header
              _buildHeader(context, textColor, surfaceColor, borderColor),

              // Messages list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  itemCount: service.messages.length +
                      (service.isLoading ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == service.messages.length) {
                      return const FlowTypingIndicator();
                    }
                    return FlowChatMessageBubble(
                      message: service.messages[i],
                    );
                  },
                ),
              ),

              // Input bar
              FlowChatInput(
                onSubmit: (text) =>
                    service.handleUserMessage(text),
                enabled: !service.isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color textColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // Bot avatar
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  LumioColors.primary.withOpacity(0.8),
                  LumioColors.primary,
                ],
              ),
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Goal Assistant',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Powered by AI',
                  style: TextStyle(
                    color: LumioColors.textSecondary(context),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // Clear chat button
          IconButton(
            onPressed: () {
              final service = context.read<FlowChatService>();
              service.handleUserMessage('reset');
            },
            icon: Icon(
              Icons.refresh_rounded,
              color: LumioColors.textSecondary(context),
              size: 18,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Reset conversation',
          ),
          const SizedBox(width: 8),
          // Close button
          GestureDetector(
            onTap: widget.onClose,
            child: Icon(
              Icons.close_rounded,
              color: LumioColors.textSecondary(context),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
