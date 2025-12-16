import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/voice_flow_controller.dart';
import '../theme/app_theme.dart';
import 'unified_goal_editor_screen.dart';

class HandsFreeScreen extends StatefulWidget {
  const HandsFreeScreen({super.key});

  @override
  State<HandsFreeScreen> createState() => _HandsFreeScreenState();
}

class _HandsFreeScreenState extends State<HandsFreeScreen> {
  late final VoiceFlowController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VoiceFlowController();
    // Start session after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.startSession();
      _controller.addListener(_onVoiceStateChanged);
    });
  }

  void _onVoiceStateChanged() {
    if (!mounted) return;
    
    // Check if we have a completed action
    if (_controller.lastResponse != null && _controller.lastResponse!.isAction) {
       _controller.stopSession();
       
       // Navigate to review screen
       final actionData = _controller.lastResponse!.actionData;
       if (actionData != null) {
         Navigator.of(context).pushReplacement(
           MaterialPageRoute(
             builder: (context) => UnifiedGoalEditorScreen(aiResult: actionData),
           ),
         );
       }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onVoiceStateChanged);
    _controller.stopSession();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: Colors.black, // Immersive dark mode
        body: SafeArea(
          child: Consumer<VoiceFlowController>(
            builder: (context, controller, child) {
              return Stack(
                children: [
                  // Close Button
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 32),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  // Main Content
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      
                      // Status Text
                      Text(
                        _getStatusText(controller.state),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18, 
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ).animate()
                       .fadeIn(duration: 600.ms),

                      const SizedBox(height: 48),

                      // Visualizer Circle
                      _buildVisualizer(controller.state),

                      const SizedBox(height: 48),

                      // Transcript / System Message area
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          controller.state == VoiceState.speaking
                              ? controller.lastSystemMessage
                              : controller.currentTranscript.isEmpty 
                                  ? "..." 
                                  : '"${controller.currentTranscript}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: controller.state == VoiceState.speaking 
                                ? AppTheme.primaryColor 
                                : Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ).animate(target: controller.state == VoiceState.speaking ? 1 : 0)
                         .slideY(begin: 0.1, end: 0, duration: 400.ms)
                         .fadeIn(),
                      ),

                      const Spacer(),
                      
                      // Hint
                      if (controller.state == VoiceState.listening)
                         const Text(
                          "Tap to stop",
                          style: TextStyle(color: Colors.white38),
                        ).animate().fadeIn(),
                        
                      const SizedBox(height: 32),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _getStatusText(VoiceState state) {
    switch (state) {
      case VoiceState.idle: return "Ready";
      case VoiceState.listening: return "Listening...";
      case VoiceState.processing: return "Thinking...";
      case VoiceState.speaking: return "Lumio";
      case VoiceState.error: return "Error";
    }
  }

  Widget _buildVisualizer(VoiceState state) {
    Color color;
    bool isAnimating = false;

    switch (state) {
      case VoiceState.listening:
        color = AppTheme.primaryColor; // Orange
        isAnimating = true;
        break;
      case VoiceState.processing:
        color = Colors.purpleAccent;
        isAnimating = true;
        break;
      case VoiceState.speaking:
        color = Colors.blueAccent;
        isAnimating = true;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: Center(
        child: Icon(
          state == VoiceState.listening ? Icons.mic : Icons.graphic_eq,
          color: color,
          size: 48,
        ),
      ),
    )
    .animate(target: isAnimating ? 1 : 0, onPlay: (c) => c.repeat(reverse: true))
    .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1000.ms)
    .boxShadow(
      begin: BoxShadow(color: color.withOpacity(0.2), blurRadius: 20, spreadRadius: 0),
      end: BoxShadow(color: color.withOpacity(0.6), blurRadius: 40, spreadRadius: 10),
      duration: 1000.ms,
    );
  }
}
