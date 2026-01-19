import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return PopScope(
      canPop: _allowPop,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // User tried to go back (System Back or AppBar Back)
        // We intercepted it. Now save and pop manually.
        _saveAndPop();
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.grey[50], // Consistent background
        appBar: AppBar(
          title: const Text("Goal Settings"),
          backgroundColor: Colors.transparent, // match Unified Editor
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
            onPressed: () {
              // Handle AppBar back button explicitly to trigger PopScope logic or call save directly
              // Calling maybePop will trigger PopScope
              Navigator.of(context).maybePop();
            },
          ),
          actions: [
            TextButton(
              onPressed: _saveCompete,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Enable Toggle
            SwitchListTile.adaptive(
              title: const Text("Enable Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
              value: _enableNotifications,
              onChanged: (val) => setState(() => _enableNotifications = val),
              activeColor: AppTheme.primaryColor,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            const SizedBox(height: 16),

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
                    _buildSectionHeader("Default Time"),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _notificationTime.format(context), 
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.normal),
                      ),
                      trailing: const Icon(Icons.access_time_rounded),
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
                    const SizedBox(height: 24),

                    // 3. Frequency
                    _buildSectionHeader("Frequency"),
                    Wrap(
                      spacing: 8,
                      children: NotificationFrequency.values.map((f) {
                        return ChoiceChip(
                          label: Text(_frequencyName(f)),
                          selected: _frequency == f,
                          onSelected: (selected) {
                            if (selected) setState(() => _frequency = f);
                          },
                          selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: _frequency == f ? AppTheme.primaryColor : (isDark ? Colors.white : Colors.black),
                            fontWeight: _frequency == f ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // 4. Alerts Timing
                    _buildSectionHeader("When to Alert"),
                    ...AlertTiming.values.map((t) {
                      return RadioListTile<AlertTiming>(
                        title: Text(_timingName(t)),
                        value: t,
                        groupValue: _alertTiming,
                        onChanged: (val) {
                          if (val != null) setState(() => _alertTiming = val);
                        },
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primaryColor,
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
                    
                    const SizedBox(height: 24),

                    // 5. Tone
                    _buildSectionHeader("Notification Tone"),
                    Wrap(
                      spacing: 8,
                      children: NotificationTone.values.map((t) {
                        return ChoiceChip(
                          label: Text(_toneName(t)),
                          selected: _tone == t,
                          onSelected: (selected) {
                            if (selected) setState(() => _tone = t);
                          },
                          // Reusing similar styling
                          selectedColor: Colors.purple.withOpacity(0.2), // Different color for variety
                           labelStyle: TextStyle(
                            color: _tone == t ? Colors.purple : (isDark ? Colors.white : Colors.black),
                            fontWeight: _tone == t ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.grey,
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
