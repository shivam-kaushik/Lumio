import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/flow_chat_service.dart';
import '../../theme/theme.dart';

/// Renders a single message bubble in the flow chat panel.
class FlowChatMessageBubble extends StatelessWidget {
  final FlowMessage message;

  const FlowChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isSuccess) return _SuccessCard(message: message);
    if (message.isError) return _ErrorBubble(message: message);
    if (message.isUser) return _UserBubble(message: message);
    return _BotBubble(message: message);
  }
}

// ---------------------------------------------------------------------------
// Bot bubble
// ---------------------------------------------------------------------------

class _BotBubble extends StatelessWidget {
  final FlowMessage message;
  const _BotBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF2D261E) : const Color(0xFFF2EEE9);
    final textColor = isDark ? Colors.white : const Color(0xFF1A150F);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Mini avatar
          Container(
            width: 28,
            height: 28,
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
                color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: -0.04, end: 0);
  }
}

// ---------------------------------------------------------------------------
// User bubble
// ---------------------------------------------------------------------------

class _UserBubble extends StatelessWidget {
  final FlowMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? LumioColors.primary : const Color(0xFF1A150F);
    final textColor = isDark ? const Color(0xFF1A150F) : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.04, end: 0);
  }
}

// ---------------------------------------------------------------------------
// Success card
// ---------------------------------------------------------------------------

class _SuccessCard extends StatelessWidget {
  final FlowMessage message;
  const _SuccessCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final iconData = _iconFor(message.successType);
    final color = _colorFor(message.successType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message.text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.94, 0.94), duration: 300.ms);
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'goal':
        return Icons.flag_rounded;
      case 'task':
        return Icons.check_circle_rounded;
      case 'subtask':
        return Icons.subdirectory_arrow_right_rounded;
      default:
        return Icons.check_rounded;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'goal':
        return LumioColors.primary;
      case 'task':
        return const Color(0xFF10B981); // green
      case 'subtask':
        return const Color(0xFF8B5CF6); // purple
      default:
        return const Color(0xFF10B981);
    }
  }
}

// ---------------------------------------------------------------------------
// Error bubble
// ---------------------------------------------------------------------------

class _ErrorBubble extends StatelessWidget {
  final FlowMessage message;
  const _ErrorBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFEF4444).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFEF4444), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.text,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

// ---------------------------------------------------------------------------
// Typing indicator (three bouncing dots)
// ---------------------------------------------------------------------------

class FlowTypingIndicator extends StatelessWidget {
  const FlowTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF2D261E) : const Color(0xFFF2EEE9);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
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
                color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: LumioColors.primary.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(
                      begin: 0.5,
                      end: 1.0,
                      duration: 400.ms,
                      delay: (i * 140).ms,
                      curve: Curves.easeInOut,
                    ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
