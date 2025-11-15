import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../providers/reminder_provider.dart';
import '../theme/app_theme.dart';
import '../../core/services/nlu_parser.dart';
import '../../core/services/gpt_nlu_service.dart';
import '../../core/services/home_detection_service.dart';
import '../../data/models/reminder.dart';
import '../../core/services/permission_service.dart';
import '../widgets/smart_reminder_dialog.dart';
import 'home_setup_screen.dart';

/// Add reminder screen with natural language input
class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isCreating = false;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  Reminder? _parsedPreview;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _createReminder() async {
    final text = _textController.text.trim();

    if (text.isEmpty) {
      // Show smart dialog for manual entry
      _showSmartDialog();
      return;
    }

    // Check exact alarm permission first
    final permissionService = PermissionService();
    final hasExactAlarm = await permissionService.ensureExactAlarmPermission(
      context,
      rationale:
          'Exact alarms are needed to deliver tasks at the right time.',
    );

    if (!hasExactAlarm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exact alarm permission is required')),
        );
      }
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // First try GPT-powered parsing
      final gptParsed = await GptNluService.parseReminderText(text);

      if (gptParsed != null) {
        debugPrint('✅ GPT parsed: $gptParsed');

        // Check if location-based reminder needs home setup
        if ((gptParsed.onLeave || gptParsed.onArrive) &&
            gptParsed.locationContext == 'home') {
          final homeService = HomeDetectionService();
          final status = await homeService.getSetupStatus();

          if (!(status['isFullySetup'] as bool)) {
            // Prompt user to setup home
            final shouldSetup = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('🏠 Home Setup Required'),
                content: const Text(
                  'This task needs to know your home location. Would you like to set it up now?\n\n'
                  'Quick setup:\n'
                  '✓ Set your home GPS location on the map',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Skip'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Setup Now'),
                  ),
                ],
              ),
            );

            if (shouldSetup == true && mounted) {
              setState(() => _isCreating = false);
              // Navigate to home setup
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeSetupScreen(),
                ),
              );
              return;
            }
          }
        }

        // Convert time range strings to DateTime
        DateTime? timeRangeStart;
        DateTime? timeRangeEnd;

        if (gptParsed.timeRangeStart != null) {
          final parts = gptParsed.timeRangeStart!.split(':');
          final now = DateTime.now();
          timeRangeStart = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        }

        if (gptParsed.timeRangeEnd != null) {
          final parts = gptParsed.timeRangeEnd!.split(':');
          final now = DateTime.now();
          timeRangeEnd = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        }

        // Prepare optional location suggestion (don't auto-enable)
        Map<String, dynamic>? locationSuggestion;
        if (gptParsed.locationContext == 'home' &&
            (gptParsed.onLeave || gptParsed.onArrive)) {
          final homeService = HomeDetectionService();
          final homeLocation = await homeService.getHomeLocation();

          if (homeLocation != null) {
            locationSuggestion = {
              'context': 'home',
              'latitude': homeLocation.latitude,
              'longitude': homeLocation.longitude,
              'radius': homeLocation.radius,
            };

            debugPrint(
                '✅ Home location available (suggestion): $locationSuggestion');
          } else {
            debugPrint('⚠️ Home location not configured (no suggestion)');
          }
        }

        // Safety check: If recurring reminder with "starting now" but no dateTime, set it
        DateTime? finalTimeAt = gptParsed.dateTime;
        if (finalTimeAt == null &&
            gptParsed.isRecurring &&
            gptParsed.repeatInterval != null &&
            gptParsed.repeatUnit != null) {
          // Check if original text contains "starting now" (GPT might have missed it)
          final lowerText = text.toLowerCase();
          final hasStartingNow = RegExp(
            r'\b(starting\s+now|start\s+now|right\s+away|immediately|from\s+now)\b',
            caseSensitive: false,
          ).hasMatch(lowerText);
          
          if (hasStartingNow) {
            finalTimeAt = DateTime.now().add(const Duration(seconds: 10));
            debugPrint('⚠️ GPT parsed missed "starting now" - setting timeAt to 10 seconds from now');
          }
        }

        // Convert parsed data to Reminder object
        final reminder = Reminder(
          text: gptParsed.title,
          timeAt: finalTimeAt,
          priority: gptParsed.priority ?? ReminderPriority.medium,
          category: gptParsed.category ?? ReminderCategory.other,
          repeatInterval: gptParsed.repeatInterval,
          repeatUnit: gptParsed.repeatUnit,
          repeatEndDate: gptParsed.repeatEndDate,
          repeatOnDays: gptParsed.repeatOnDays,
          timeRangeStart: timeRangeStart,
          timeRangeEnd: timeRangeEnd,
          preferredTimeOfDay: gptParsed.preferredTimeOfDay,
          // Do not auto-set geofence here. Let user enable it in dialog.
          onLeaveContext: gptParsed.onLeave,
          onArriveContext: gptParsed.onArrive,
        );

        // Show smart dialog for confirmation/editing and pass location suggestion if available
        final result = await showDialog<Reminder>(
          context: context,
          builder: (context) => SmartReminderDialog(
            reminder: reminder,
            locationSuggestion: locationSuggestion,
          ),
        );

        if (result == null) {
          setState(() => _isCreating = false);
          return;
        }

        final reminderProvider = context.read<ReminderProvider>();
        final id = await reminderProvider.createReminder(result);

        if (!mounted) return;

        setState(() => _isCreating = false);

        if (id != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task created successfully!')),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(reminderProvider.error ?? 'Failed to create task'),
            ),
          );
        }
      } else {
        // Fallback to basic NLU parser
        if (!NLUParser.hasValidIntent(text)) {
          setState(() => _isCreating = false);
          _showSmartDialog(initialText: text);
          return;
        }

        final parsed = NLUParser.parseReminderText(text);
        final result = await showDialog<Reminder>(
          context: context,
          builder: (context) => SmartReminderDialog(reminder: parsed),
        );

        if (result == null) {
          setState(() => _isCreating = false);
          return;
        }

        final reminderProvider = context.read<ReminderProvider>();
        final id = await reminderProvider.createReminder(result);

        if (!mounted) return;

        setState(() => _isCreating = false);

        if (id != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task created successfully!')),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(reminderProvider.error ?? 'Failed to create task'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error creating reminder: $e');
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showSmartDialog({String? initialText}) async {
    final result = await showDialog<Reminder>(
      context: context,
      builder: (context) => SmartReminderDialog(
        reminder: initialText != null ? Reminder(text: initialText) : null,
      ),
    );

    if (result == null) return;

    setState(() => _isCreating = true);

    final reminderProvider = context.read<ReminderProvider>();
    final id = await reminderProvider.createReminder(result);

    if (!mounted) return;

    setState(() => _isCreating = false);

    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder created successfully!')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reminderProvider.error ?? 'Failed to create reminder'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Task'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Premium input section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      'What do you want to remember?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      'Use natural language - we\'ll figure out the rest',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXL),

                    // Premium input field with voice
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                        border: Border.all(
                          color: _isListening
                              ? AppTheme.primaryColor
                              : AppTheme.borderColor,
                          width: _isListening ? 2 : 1,
                        ),
                        boxShadow: _isListening
                            ? AppTheme.getElevationShadow(2)
                            : null,
                      ),
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'e.g., Take my keys when leaving home at 8 AM',
                          hintStyle: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(AppTheme.spacingMD),
                          suffixIcon: _isListening
                              ? Container(
                                  margin: const EdgeInsets.all(AppTheme.spacingSM),
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.mic_rounded,
                                    color: AppTheme.errorColor,
                                    size: 24,
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.mic_outlined),
                                  tooltip: 'Voice input',
                                  onPressed: () async {
                                    HapticFeedback.mediumImpact();
                                    final permissionService = PermissionService();
                                    final granted =
                                        await permissionService.ensureMicrophonePermission(
                                      context,
                                      rationale:
                                          'Microphone access is required for voice input.',
                                    );
                                    if (!granted) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Microphone permission is required for voice input.'),
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    if (!_isListening) {
                                      debugPrint('🎤 Voice Input: Initializing speech recognition...');
                                      final available = await _speech.initialize(
                                        onStatus: (status) {
                                          debugPrint('🎤 Voice Input: Status changed: $status');
                                          if (mounted) {
                                            if (status == 'done' ||
                                                status == 'notListening' ||
                                                status == 'canceled') {
                                              debugPrint('🎤 Voice Input: Stopped listening');
                                              setState(() => _isListening = false);
                                              _speech.stop();
                                            } else if (status == 'listening') {
                                              debugPrint('🎤 Voice Input: Now listening...');
                                              setState(() => _isListening = true);
                                            }
                                          }
                                        },
                                        onError: (error) {
                                          debugPrint('❌ Voice Input Error: ${error.errorMsg}');
                                          if (mounted) {
                                            setState(() => _isListening = false);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Speech recognition error: ${error.errorMsg}'),
                                              ),
                                            );
                                          }
                                        },
                                      );
                                      
                                      if (available) {
                                        debugPrint('✅ Voice Input: Speech recognition available');
                                        if (mounted) {
                                          setState(() => _isListening = true);
                                        }
                                        debugPrint('🎤 Voice Input: Starting to listen...');
                                        _speech.listen(
                                          onResult: (result) {
                                            debugPrint('🎤 Voice Input: Result - "${result.recognizedWords}" (final=${result.finalResult})');
                                            if (mounted) {
                                              setState(() {
                                                _textController.text =
                                                    result.recognizedWords;
                                              });
                                              if (result.recognizedWords.trim().isNotEmpty &&
                                                  NLUParser.hasValidIntent(
                                                      result.recognizedWords)) {
                                                debugPrint('✅ Voice Input: Valid intent detected, updating preview');
                                                _parsedPreview =
                                                    NLUParser.parseReminderText(
                                                        result.recognizedWords);
                                              }
                                            }
                                          },
                                          localeId: 'en_US',
                                          listenMode: stt.ListenMode.confirmation,
                                          cancelOnError: true,
                                          partialResults: true,
                                        );
                                      } else {
                                        debugPrint('❌ Voice Input: Speech recognition not available');
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Speech recognition is not available on this device.'),
                                            ),
                                          );
                                        }
                                      }
                                    } else {
                                      debugPrint('🎤 Voice Input: Stopping speech recognition...');
                                      setState(() => _isListening = false);
                                      await _speech.stop();
                                      debugPrint('✅ Voice Input: Stopped listening');
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Stopped listening'),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        autofocus: true,
                        style: theme.textTheme.bodyLarge,
                        onChanged: (text) {
                          if (text.trim().isNotEmpty && NLUParser.hasValidIntent(text)) {
                            setState(() {
                              _parsedPreview = NLUParser.parseReminderText(text);
                            });
                          } else {
                            setState(() {
                              _parsedPreview = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // Premium preview card
                    if (_parsedPreview != null)
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingMD),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 20,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: AppTheme.spacingSM),
                                Text(
                                  'Preview',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            Text(
                              _parsedPreview!.text,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingSM),
                            Text(
                              _parsedPreview!.getContextDescription(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: AppTheme.spacingXL),

                    // Quick actions section
                    if (_textController.text.isEmpty) ...[
                      Text(
                        'Quick start',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                      Wrap(
                        spacing: AppTheme.spacingSM,
                        runSpacing: AppTheme.spacingSM,
                        children: [
                          _buildQuickActionChip(
                            context,
                            'Every Monday at 9am',
                            Icons.calendar_today_rounded,
                          ),
                          _buildQuickActionChip(
                            context,
                            'When I leave home',
                            Icons.home_rounded,
                          ),
                          _buildQuickActionChip(
                            context,
                            'Tomorrow at 5pm',
                            Icons.schedule_rounded,
                          ),
                          _buildQuickActionChip(
                            context,
                            'Daily at 8am',
                            Icons.repeat_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingXL),
                      
                      // Examples section
                      Text(
                        'Examples',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                      ...NLUParser.getSuggestions('').take(4).map((phrase) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.lightbulb_outline_rounded,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            title: Text(
                              phrase,
                              style: theme.textTheme.bodyMedium,
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _textController.text = phrase;
                                if (NLUParser.hasValidIntent(phrase)) {
                                  _parsedPreview = NLUParser.parseReminderText(phrase);
                                }
                              });
                            },
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingMD,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: AppTheme.spacingXL),
                    ],
                  ],
                ),
              ),
            ),
            
            // Sticky create button
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : () {
                      HapticFeedback.mediumImpact();
                      _createReminder();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingMD,
                      ),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Create Task',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(BuildContext context, String text, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _textController.text = text;
              if (NLUParser.hasValidIntent(text)) {
                _parsedPreview = NLUParser.parseReminderText(text);
              }
            });
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMD,
              vertical: AppTheme.spacingSM,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: AppTheme.spacingSM),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
