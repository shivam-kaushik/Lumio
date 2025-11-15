import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/permission_service.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

/// Minimal settings screen for MVP
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final PermissionService _permissionService = PermissionService();

  bool _notificationsEnabled = false;
  bool _exactAlarmEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _refreshStatuses() async {
    final notif = await _permissionService.hasNotificationPermission();
    final exactAlarm = await _permissionService.hasExactAlarmPermission();

    setState(() {
      _notificationsEnabled = notif;
      _exactAlarmEnabled = exactAlarm;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Custom AppBar
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: AppTheme.spacingLG,
            right: AppTheme.spacingMD,
            bottom: AppTheme.spacingMD,
          ),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            border: Border(
              bottom: BorderSide(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Body content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshStatuses,
            color: AppTheme.primaryColor,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingMD,
                AppTheme.spacingMD,
                AppTheme.spacingMD,
                120, // keep above bottom nav bar
              ),
              children: [
                // Theme Settings
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                  child: Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) {
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                        side: const BorderSide(color: AppTheme.borderColor, width: 1),
                      ),
                      color: AppTheme.surfaceColor,
                      child: SwitchListTile(
                        secondary: Icon(
                          themeProvider.isDarkMode(context)
                              ? Icons.dark_mode
                              : Icons.light_mode,
                        ),
                        title: Text(themeProvider.isDarkMode(context)
                            ? 'Dark Mode'
                            : 'Light Mode'),
                        value: themeProvider.themeMode == ThemeMode.dark,
                        onChanged: (value) {
                          themeProvider.setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spacingLG),
                // Permissions
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                  child: Text(
                    'Permissions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    side: const BorderSide(color: AppTheme.borderColor, width: 1),
                  ),
                  color: AppTheme.surfaceColor,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.notifications),
                        title: const Text('Notifications'),
                        subtitle: Text(
                          _notificationsEnabled ? 'Enabled' : 'Disabled',
                          style: TextStyle(
                            color: _notificationsEnabled
                                ? AppTheme.successColor
                                : AppTheme.textSecondary,
                          ),
                        ),
                        trailing: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                            ),
                          ),
                          onPressed: () async {
                            final granted =
                                await _permissionService.ensureNotificationPermission(
                              context,
                              rationale:
                                  'Notifications are required to deliver reminders.',
                            );
                            if (granted) {
                              _refreshStatuses();
                            }
                          },
                          child: const Text('Manage'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.schedule),
                        title: const Text('Exact Alarms'),
                        subtitle: Text(
                          _exactAlarmEnabled ? 'Enabled' : 'Disabled',
                          style: TextStyle(
                            color: _exactAlarmEnabled
                                ? AppTheme.successColor
                                : AppTheme.textSecondary,
                          ),
                        ),
                        trailing: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                            ),
                          ),
                          onPressed: () async {
                            final granted =
                                await _permissionService.ensureExactAlarmPermission(
                              context,
                              rationale:
                                  'Exact alarms are needed for precise reminder delivery.',
                            );
                            if (granted) {
                              _refreshStatuses();
                            }
                          },
                          child: const Text('Manage'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLG),
                // App Settings
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    side: const BorderSide(color: AppTheme.borderColor, width: 1),
                  ),
                  color: AppTheme.surfaceColor,
                  child: ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('App Settings'),
                    subtitle: const Text('Open system app settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await _permissionService.openSettings();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
