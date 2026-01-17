import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/permission_service.dart';
import '../providers/theme_provider.dart';
import '../providers/growth_provider.dart'; // NEW
import '../theme/app_theme.dart';
import '../widgets/modern_smart_card.dart';
import '../widgets/persona_selection_widget.dart'; // NEW
import '../screens/avatar_editor_screen.dart'; // NEW

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
                    'AI Coach',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark 
                          ? AppTheme.darkTextPrimary 
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                const PersonaSelectionWidget(),
                const SizedBox(height: AppTheme.spacingSM),
                
                // Profile Picture Setting
                Consumer<GrowthProvider>(
                  builder: (context, provider, _) {
                    return ModernSmartCard(
                      elevationLevel: 1,
                      child: Column(
                        children: [
                          SwitchListTile(
                             title: Text(
                                "Use Avatar as Profile Picture",
                                 style: TextStyle(
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                             ),
                             subtitle: Text(
                                "Show your customized avatar in the app",
                                style: TextStyle(
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                             ),
                             value: provider.showAvatarInProfile, 
                             onChanged: (val) => provider.toggleProfileImageSource(val),
                             activeColor: AppTheme.primaryColor,
                          ),
                          if (provider.showAvatarInProfile)
                              ListTile(
                                  leading: const Icon(Icons.edit_rounded, color: AppTheme.primaryColor),
                                  title: const Text("Customize Avatar", style: TextStyle(fontWeight: FontWeight.w600)),
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (c) => const AvatarEditorScreen()),
                                  ),
                              ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spacingLG),

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
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _getThemeIcon(themeProvider.themeMode),
                          color: isDark 
                              ? AppTheme.darkTextPrimary 
                              : AppTheme.textPrimary,
                        ),
                        title: Text(
                          'App Theme',
                          style: TextStyle(
                            color: isDark 
                                ? AppTheme.darkTextPrimary 
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _getThemeModeName(themeProvider.themeMode),
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
                        onTap: () => _showThemeSelectionDialog(context, themeProvider),
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
  void _showThemeSelectionDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return AlertDialog(
          title: const Text('Choose Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(
                context, 
                themeProvider, 
                ThemeMode.light, 
                'Light Mode', 
                Icons.light_mode_rounded,
                isDark,
              ),
              _buildThemeOption(
                context, 
                themeProvider, 
                ThemeMode.dark, 
                'Dark Mode', 
                Icons.dark_mode_rounded,
                 isDark,
              ),
              _buildThemeOption(
                context, 
                themeProvider, 
                ThemeMode.system, 
                'System Default', 
                Icons.settings_system_daydream_rounded,
                 isDark,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider provider,
    ThemeMode mode,
    String label,
    IconData icon,
    bool isDarkDialog,
  ) {
    final isSelected = provider.themeMode == mode;
    return RadioListTile<ThemeMode>(
      value: mode,
      groupValue: provider.themeMode,
      onChanged: (value) {
        if (value != null) {
          provider.setThemeMode(value);
          Navigator.pop(context);
        }
      },
      title: Text(
        label,
        style: TextStyle(
            color: isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        ),
      ),
      secondary: Icon(
        icon,
        color: isSelected ? AppTheme.primaryColor : (isDarkDialog ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
      ),
      activeColor: AppTheme.primaryColor,
      contentPadding: EdgeInsets.zero,
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.settings_brightness_rounded;
    }
  }
}
