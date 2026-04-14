import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Text input bar at the bottom of the flow chat panel.
class FlowChatInput extends StatefulWidget {
  final ValueChanged<String> onSubmit;
  final bool enabled;

  const FlowChatInput({
    super.key,
    required this.onSubmit,
    this.enabled = true,
  });

  @override
  State<FlowChatInput> createState() => _FlowChatInputState();
}

class _FlowChatInputState extends State<FlowChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? const Color(0xFF2D261E) : Colors.white;
    final textColor =
        isDark ? Colors.white : const Color(0xFF1A150F);
    final hintColor = isDark ? Colors.grey[500]! : Colors.grey[400]!;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : LumioColors.border(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF201A12) : const Color(0xFFF8F7F6),
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          final hasText = value.text.trim().isNotEmpty;
          return Row(
            children: [
              // Input field
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    style: TextStyle(
                        color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: widget.enabled
                          ? 'Type a message…'
                          : 'Please wait…',
                      hintStyle: TextStyle(
                          color: hintColor, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send button
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasText && widget.enabled
                      ? LumioColors.primary
                      : LumioColors.primary.withOpacity(0.3),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _send,
                    customBorder: const CircleBorder(),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
