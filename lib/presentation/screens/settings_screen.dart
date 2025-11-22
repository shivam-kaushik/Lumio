import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/permission_service.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_smart_card.dart';

/// Settings screen with app preferences and permissions
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
  bool _locationEnabled = false;
  bool _locationAlwaysEnabled = false;
  bool _microphoneEnabled = false;

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
    final location = await _permissionService.hasLocationPermission();
    final locationAlways = await _permissionService.hasLocationAlwaysPermission();
    final microphone = await _permissionService.hasMicrophonePermission();

    setState(() {
      _notificationsEnabled = notif;
      _exactAlarmEnabled = exactAlarm;
      _locationEnabled = location;
      _locationAlwaysEnabled = locationAlways;
      _microphoneEnabled = microphone;
    });
  }

  Future<void> _openNotificationSettings() async {
    if (!mounted) return;
    // Open system notification settings
    final granted = await _permissionService.ensureNotificationPermission(
      context,
      rationale: 'Notifications are required to deliver reminders. Please enable notifications in app settings.',
    );
    if (granted && mounted) {
      _refreshStatuses();
    }
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
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  color: isDark 
                      ? AppTheme.darkTextPrimary 
                      : AppTheme.textPrimary,
                ),
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
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingMD,
                AppTheme.spacingMD,
                AppTheme.spacingMD,
                120, // keep above bottom nav bar
              ),
              children: [
                // Appearance Settings
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                  child: Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark 
                          ? AppTheme.darkTextPrimary 
                          : AppTheme.textPrimary,
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
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          color: isDark 
                              ? AppTheme.darkTextPrimary 
                              : AppTheme.textPrimary,
                        ),
                        title: Text(
                          'Dark Mode',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextPrimary 
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          themeProvider.isDarkMode(context)
                              ? 'Dark theme enabled'
                              : 'Light theme enabled',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextSecondary 
                                : AppTheme.textSecondary,
                            fontSize: 12,
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
                
                // Notifications
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                  child: Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark 
                          ? AppTheme.darkTextPrimary 
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                ModernSmartCard(
                  useGradient: true,
                  elevationLevel: 1,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.notifications_rounded,
                      color: isDark 
                          ? AppTheme.darkTextPrimary 
                          : AppTheme.textPrimary,
                    ),
                    title: Text(
                      'Notification Settings',
                      style: TextStyle(
                        color: isDark 
                            ? AppTheme.darkTextPrimary 
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _notificationsEnabled 
                          ? 'Notifications are enabled' 
                          : 'Notifications are disabled',
                      style: TextStyle(
                        color: _notificationsEnabled
                            ? AppTheme.successColor
                            : (isDark 
                                ? AppTheme.darkTextSecondary 
                                : AppTheme.textSecondary),
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: isDark 
                          ? AppTheme.darkTextTertiary 
                          : AppTheme.textTertiary,
                    ),
                    onTap: _openNotificationSettings,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLG),
                
                // Permissions
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                  child: Text(
                    'Permissions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark 
                          ? AppTheme.darkTextPrimary 
                          : AppTheme.textPrimary,
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
                        enabled: false,
                        leading: Icon(
                          Icons.schedule_rounded,
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _exactAlarmEnabled 
                              ? 'Enabled for precise reminders' 
                              : 'Disabled - reminders may be delayed',
                          style: TextStyle(
                            color: _exactAlarmEnabled
                                ? AppTheme.successColor
                                : (isDark 
                                    ? AppTheme.darkTextSecondary 
                                    : AppTheme.textSecondary),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final granted =
                                  await _permissionService.ensureExactAlarmPermission(
                                context,
                                rationale:
                                    'Exact alarms are needed for precise reminder delivery.',
                              );
                              if (granted && mounted) {
                                _refreshStatuses();
                              }
                            },
                            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark 
                                      ? AppTheme.darkBorder 
                                      : AppTheme.borderColor,
                                ),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                              ),
                              child: Text(
                                'Manage',
                                style: TextStyle(
                                  color: isDark 
                                      ? AppTheme.darkTextPrimary 
                                      : AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
                        enabled: false,
                        leading: Icon(
                          Icons.location_on_rounded,
                          color: isDark 
                              ? AppTheme.darkTextPrimary 
                              : AppTheme.textPrimary,
                        ),
                        title: Text(
                          'Location',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextPrimary 
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _locationEnabled 
                              ? (_locationAlwaysEnabled 
                                  ? 'Always allowed' 
                                  : 'While using app') 
                              : 'Disabled',
                          style: TextStyle(
                            color: _locationEnabled
                                ? AppTheme.successColor
                                : (isDark 
                                    ? AppTheme.darkTextSecondary 
                                    : AppTheme.textSecondary),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final granted =
                                  await _permissionService.ensureLocationPermission(
                                context,
                                rationale:
                                    'Location is needed for location-based reminders.',
                              );
                              if (granted && mounted) {
                                _refreshStatuses();
                              }
                            },
                            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark 
                                      ? AppTheme.darkBorder 
                                      : AppTheme.borderColor,
                                ),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                              ),
                              child: Text(
                                'Manage',
                                style: TextStyle(
                                  color: isDark 
                                      ? AppTheme.darkTextPrimary 
                                      : AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
                        enabled: false,
                        leading: Icon(
                          Icons.mic_rounded,
                          color: isDark 
                              ? AppTheme.darkTextPrimary 
                              : AppTheme.textPrimary,
                        ),
                        title: Text(
                          'Microphone',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextPrimary 
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _microphoneEnabled 
                              ? 'Enabled for voice input' 
                              : 'Disabled',
                          style: TextStyle(
                            color: _microphoneEnabled
                                ? AppTheme.successColor
                                : (isDark 
                                    ? AppTheme.darkTextSecondary 
                                    : AppTheme.textSecondary),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final granted =
                                  await _permissionService.ensureMicrophonePermission(
                                context,
                                rationale:
                                    'Microphone is needed for voice input when creating reminders.',
                              );
                              if (granted && mounted) {
                                _refreshStatuses();
                              }
                            },
                            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark 
                                      ? AppTheme.darkBorder 
                                      : AppTheme.borderColor,
                                ),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                              ),
                              child: Text(
                                'Manage',
                                style: TextStyle(
                                  color: isDark 
                                      ? AppTheme.darkTextPrimary 
                                      : AppTheme.textPrimary,
                                  fontSize: 12,
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
                const SizedBox(height: AppTheme.spacingLG),
                
                // App Settings
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                  child: Text(
                    'App Settings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark 
                          ? AppTheme.darkTextPrimary 
                          : AppTheme.textPrimary,
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
                          Icons.settings_applications_rounded,
                          color: isDark 
                              ? AppTheme.darkTextPrimary 
                              : AppTheme.textPrimary,
                        ),
                        title: Text(
                          'System Settings',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextPrimary 
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Open device settings',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextSecondary 
                                : AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: isDark 
                              ? AppTheme.darkTextTertiary 
                              : AppTheme.textTertiary,
                        ),
                        onTap: () async {
                          await _permissionService.openSettings();
                        },
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
                          Icons.storage_rounded,
                          color: isDark 
                              ? AppTheme.darkTextPrimary 
                              : AppTheme.textPrimary,
                        ),
                        title: Text(
                          'Data & Storage',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextPrimary 
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Manage app data and cache',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextSecondary 
                                : AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: isDark 
                              ? AppTheme.darkTextTertiary 
                              : AppTheme.textTertiary,
                        ),
                        onTap: () {
                          _showDataManagementDialog(context);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLG),
                
                // About
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                  child: Text(
                    'About',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark 
                          ? AppTheme.darkTextPrimary 
                          : AppTheme.textPrimary,
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
                          Icons.info_outline_rounded,
                          color: isDark 
                              ? AppTheme.darkTextPrimary 
                              : AppTheme.textPrimary,
                        ),
                        title: Text(
                          'App Version',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextPrimary 
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          '1.0.0',
                          style: TextStyle(
                            fontSize: 12,
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
                          Icons.description_rounded,
                          color: isDark 
                              ? AppTheme.darkTextPrimary 
                              : AppTheme.textPrimary,
                        ),
                        title: Text(
                          'Privacy Policy',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextPrimary 
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                          color: isDark 
                              ? AppTheme.darkTextTertiary 
                              : AppTheme.textTertiary,
                        ),
                        onTap: () {
                          // TODO: Add privacy policy URL
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Privacy policy coming soon'),
                            ),
                          );
                        },
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
                          Icons.description_rounded,
                          color: isDark 
                              ? AppTheme.darkTextPrimary 
                              : AppTheme.textPrimary,
                        ),
                        title: Text(
                          'Terms of Service',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextPrimary 
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                          color: isDark 
                              ? AppTheme.darkTextTertiary 
                              : AppTheme.textTertiary,
                        ),
                        onTap: () {
                          // TODO: Add terms of service URL
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Terms of service coming soon'),
                            ),
                          );
                        },
                      ),
                    ],
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

  void _showDataManagementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data & Storage'),
        content: const Text(
          'Data management features coming soon. You can clear app data from system settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _permissionService.openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
