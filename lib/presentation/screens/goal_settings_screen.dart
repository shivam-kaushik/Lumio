import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../../data/models/goal_settings.dart';

class GoalSettingsScreen extends StatefulWidget {
  final GoalSettings? initialSettings;
  
  const GoalSettingsScreen({super.key, this.initialSettings});

  @override
  State<GoalSettingsScreen> createState() => _GoalSettingsScreenState();
}

class _GoalSettingsScreenState extends State<GoalSettingsScreen> {
  late TimeOfDay _notificationTime;
  late NotificationFrequency _frequency;
  late AlertTiming _alertTiming;
  late int _customAlertMinutes;
  late NotificationTone _tone;
  late bool _enableNotifications;

  @override
  void initState() {
    super.initState();
    final settings = widget.initialSettings ?? GoalSettings();
    _notificationTime = settings.notificationTime ?? const TimeOfDay(hour: 9, minute: 0);
    _frequency = settings.frequency;
    _alertTiming = settings.alertTiming;
    _customAlertMinutes = settings.customAlertMinutes ?? 30;
    _tone = settings.tone;
    _enableNotifications = settings.enableNotifications;
  }

  bool _allowPop = false; // Flag to control pop

  void _saveAndPop() {
    debugPrint('💾 GoalSettingsScreen: _saveAndPop called (Auto-Save)');
    final newSettings = GoalSettings(
      notificationTime: _notificationTime,
      frequency: _frequency,
      alertTiming: _alertTiming,
      customAlertMinutes: _alertTiming == AlertTiming.custom ? _customAlertMinutes : null,
      tone: _tone,
      enableNotifications: _enableNotifications,
    );
    
    // Set flag to allow the pop to happen
    setState(() => _allowPop = true);
    
    // Wait for the build to complete so PopScope sees canPop: true
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('📤 GoalSettingsScreen: Popping with settings: ${newSettings.toMap()}');
        Navigator.of(context).pop(newSettings);
      }
    });
  }

  void _saveCompete() {
    // Manual save button just triggers the shared logic
    _saveAndPop();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = LumioColors.textPrimary(context);
    final textSecondary = LumioColors.textSecondary(context);
    // Clears main tab bar + elevated center FAB + home indicator (nested tab Navigator).
    final bottomClearance =
        LumioSpacing.md + 96 + MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: _allowPop,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // User tried to go back (System Back or AppBar Back)
        // We intercepted it. Now save and pop manually.
        _saveAndPop();
      },
      child: Scaffold(
        backgroundColor: LumioColors.background(context),
        appBar: AppBar(
          title: Text(
            'Goal Settings',
            style: LumioTypography.titleLarge.copyWith(color: textPrimary),
          ),
          backgroundColor: LumioColors.background(context),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textPrimary),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              Navigator.of(context).maybePop();
            },
          ),
          actions: [
            TextButton(
              onPressed: _saveCompete,
              child: Text(
                'Save',
                style: LumioTypography.labelLarge.copyWith(
                  color: LumioColors.primary,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            LumioSpacing.md,
            LumioSpacing.sm,
            LumioSpacing.md,
            bottomClearance,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // 1. Enable Toggle
            SwitchTheme(
              data: SwitchThemeData(
                trackOutlineColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? LumioColors.primary
                      : LumioColors.border(context),
                ),
                trackColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? LumioColors.primary
                      : LumioColors.surface(context),
                ),
                thumbColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : textSecondary,
                ),
              ),
              child: SwitchListTile.adaptive(
                title: Text(
                  'Enable Notifications',
                  style: LumioTypography.titleSmall.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: _enableNotifications,
                onChanged: (val) => setState(() => _enableNotifications = val),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Divider(color: LumioColors.border(context)),
            const SizedBox(height: LumioSpacing.md),

            // Only show others if enabled
            AnimatedOpacity(
              opacity: _enableNotifications ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_enableNotifications,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Notification Time
                    _buildSectionHeader(context, 'Default Time'),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _notificationTime.format(context),
                        style: LumioTypography.headlineSmall.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.access_time_rounded,
                        color: LumioColors.primary,
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context, 
                          initialTime: _notificationTime,
                        );
                        if (picked != null) {
                          setState(() => _notificationTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: LumioSpacing.lg),

                    // 3. Frequency
                    _buildSectionHeader(context, 'Frequency'),
                    Wrap(
                      spacing: LumioSpacing.sm,
                      runSpacing: LumioSpacing.sm,
                      children: NotificationFrequency.values.map((f) {
                        final selected = _frequency == f;
                        return ChoiceChip(
                          label: Text(_frequencyName(f)),
                          selected: selected,
                          onSelected: (sel) {
                            if (sel) setState(() => _frequency = f);
                          },
                          selectedColor: LumioColors.primaryLight,
                          backgroundColor: LumioColors.surface(context),
                          side: BorderSide(
                            color: selected
                                ? LumioColors.primary
                                : LumioColors.border(context),
                          ),
                          labelStyle: LumioTypography.labelMedium.copyWith(
                            color: selected
                                ? LumioColors.primary
                                : textPrimary,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: LumioSpacing.lg),

                    // 4. Alerts Timing
                    _buildSectionHeader(context, 'When to Alert'),
                    ...AlertTiming.values.map((t) {
                      return RadioListTile<AlertTiming>(
                        title: Text(
                          _timingName(t),
                          style: LumioTypography.bodyLarge.copyWith(
                            color: textPrimary,
                          ),
                        ),
                        value: t,
                        groupValue: _alertTiming,
                        onChanged: (val) {
                          if (val != null) setState(() => _alertTiming = val);
                        },
                        contentPadding: EdgeInsets.zero,
                        fillColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? LumioColors.primary.withValues(alpha: 0.12)
                              : null,
                        ),
                        activeColor: LumioColors.primary,
                      );
                    }),
                    
                    if (_alertTiming == AlertTiming.custom)
                       Padding(
                         padding: const EdgeInsets.only(left: 16, top: 0),
                         child: Row(
                           children: [
                             SizedBox(
                               width: 80,
                               child: TextFormField(
                                 initialValue: _customAlertMinutes.toString(),
                                 keyboardType: TextInputType.number,
                                 decoration: const InputDecoration(
                                   labelText: "Min",
                                   isDense: true,
                                 ),
                                 onChanged: (val) {
                                   final parsed = int.tryParse(val);
                                   if (parsed != null) _customAlertMinutes = parsed;
                                 },
                               ),
                             ),
                             const SizedBox(width: 12),
                             const Text("minutes before task starts"),
                           ],
                         ),
                       ),
                    
                    const SizedBox(height: LumioSpacing.lg),

                    // 5. Tone
                    _buildSectionHeader(context, 'Notification Tone'),
                    Wrap(
                      spacing: LumioSpacing.sm,
                      runSpacing: LumioSpacing.sm,
                      children: NotificationTone.values.map((t) {
                        final selected = _tone == t;
                        return ChoiceChip(
                          label: Text(_toneName(t)),
                          selected: selected,
                          onSelected: (sel) {
                            if (sel) setState(() => _tone = t);
                          },
                          selectedColor: LumioColors.primaryLight,
                          backgroundColor: LumioColors.surface(context),
                          side: BorderSide(
                            color: selected
                                ? LumioColors.primary
                                : LumioColors.border(context),
                          ),
                          labelStyle: LumioTypography.labelMedium.copyWith(
                            color: selected
                                ? LumioColors.primary
                                : textPrimary,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LumioSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: LumioTypography.labelMedium.copyWith(
          letterSpacing: 1.2,
          color: LumioColors.textSecondary(context),
        ),
      ),
    );
  }

  String _frequencyName(NotificationFrequency f) {
    switch (f) {
      case NotificationFrequency.once: return "Once";
      case NotificationFrequency.daily: return "Daily";
      case NotificationFrequency.weekly: return "Weekly";
      case NotificationFrequency.monthly: return "Monthly";
      case NotificationFrequency.deadline: return "At Deadline";
    }
  }

  String _timingName(AlertTiming t) {
    switch (t) {
      case AlertTiming.atStart: return "At scheduled start time";
      case AlertTiming.atEnd: return "At scheduled end time";
      case AlertTiming.fifteenMinBefore: return "15 minutes before";
      case AlertTiming.custom: return "Custom time before";
    }
  }

  String _toneName(NotificationTone t) {
    switch (t) {
      case NotificationTone.motivational: return "Motivational";
      case NotificationTone.funny: return "Funny / Witty";
      case NotificationTone.severe: return "Severe";
      case NotificationTone.quotes: return "Quotes";
    }
  }
}
