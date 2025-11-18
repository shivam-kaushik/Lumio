import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/permission_service.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_smart_card.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppTheme.backgroundColor,
      body: Column(
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
              color: Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: isDark 
                      ? AppTheme.darkBorder 
                      : AppTheme.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Settings',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark 
                          ? AppTheme.darkTextPrimary 
                          : AppTheme.textPrimary,
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
                    return ModernSmartCard(
                      useGradient: true,
                      elevationLevel: 1,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          themeProvider.isDarkMode(context)
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          color: isDark 
                              ? AppTheme.darkTextPrimary 
                              : AppTheme.textPrimary,
                        ),
                        title: Text(
                          themeProvider.isDarkMode(context)
                              ? 'Dark Mode'
                              : 'Light Mode',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextPrimary 
                                : AppTheme.textPrimary,
                          ),
                        ),
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
                ModernSmartCard(
                  useGradient: true,
                  elevationLevel: 1,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.notifications,
                          color: isDark 
                              ? AppTheme.darkTextPrimary 
                              : AppTheme.textPrimary,
                        ),
                        title: Text(
                          'Notifications',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextPrimary 
                                : AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          _notificationsEnabled ? 'Enabled' : 'Disabled',
                          style: TextStyle(
                            color: _notificationsEnabled
                                ? AppTheme.successColor
                                : (isDark 
                                    ? AppTheme.darkTextSecondary 
                                    : AppTheme.textSecondary),
                          ),
                        ),
                        trailing: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark 
                                  ? AppTheme.darkBorder 
                                  : AppTheme.borderColor,
                            ),
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
                          child: Text(
                            'Manage',
                            style: TextStyle(
                              color: isDark 
                                  ? AppTheme.darkTextPrimary 
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: isDark 
                            ? AppTheme.darkDivider 
                            : AppTheme.dividerColor,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.schedule,
                          color: isDark 
                              ? AppTheme.darkTextPrimary 
                              : AppTheme.textPrimary,
                        ),
                        title: Text(
                          'Exact Alarms',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextPrimary 
                                : AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          _exactAlarmEnabled ? 'Enabled' : 'Disabled',
                          style: TextStyle(
                            color: _exactAlarmEnabled
                                ? AppTheme.successColor
                                : (isDark 
                                    ? AppTheme.darkTextSecondary 
                                    : AppTheme.textSecondary),
                          ),
                        ),
                        trailing: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark 
                                  ? AppTheme.darkBorder 
                                  : AppTheme.borderColor,
                            ),
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
                          child: Text(
                            'Manage',
                            style: TextStyle(
                              color: isDark 
                                  ? AppTheme.darkTextPrimary 
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLG),
                // App Settings
                ModernSmartCard(
                  useGradient: true,
                  elevationLevel: 1,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.settings,
                      color: isDark 
                          ? AppTheme.darkTextPrimary 
                          : AppTheme.textPrimary,
                    ),
                    title: Text(
                      'App Settings',
                      style: TextStyle(
                        color: isDark 
                            ? AppTheme.darkTextPrimary 
                            : AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Open system app settings',
                      style: TextStyle(
                        color: isDark 
                            ? AppTheme.darkTextSecondary 
                            : AppTheme.textSecondary,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: isDark 
                          ? AppTheme.darkTextSecondary 
                          : AppTheme.textSecondary,
                    ),
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
    ),
    );
  }
}
