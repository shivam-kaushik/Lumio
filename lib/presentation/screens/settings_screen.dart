import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/permission_service.dart';
import '../providers/theme_provider.dart';
import '../providers/growth_provider.dart';
import '../theme/theme.dart';
import '../widgets/persona_selection_widget.dart';
import '../screens/avatar_editor_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  final PermissionService _permissionService = PermissionService();
  bool _notificationsEnabled = false;
  bool _exactAlarmEnabled = false;
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
    if (state == AppLifecycleState.resumed) _refreshStatuses();
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _refreshStatuses() async {
    final notif = await _permissionService.hasNotificationPermission();
    final exactAlarm = await _permissionService.hasExactAlarmPermission();
    final microphone = await _permissionService.hasMicrophonePermission();
    if (mounted) {
      setState(() {
        _notificationsEnabled = notif;
        _exactAlarmEnabled = exactAlarm;
        _microphoneEnabled = microphone;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LumioColors.background(context),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: LumioSpacing.sm,
              right: LumioSpacing.md,
              bottom: LumioSpacing.md,
            ),
            decoration: BoxDecoration(
              color: LumioColors.background(context),
              border: Border(bottom: BorderSide(color: LumioColors.border(context), width: 1)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  color: LumioColors.textPrimary(context),
                ),
                Text('Settings', style: LumioTypography.titleLarge.copyWith(color: LumioColors.textPrimary(context))),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshStatuses,
              color: LumioColors.primary,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(LumioSpacing.md, LumioSpacing.md, LumioSpacing.md, LumioSpacing.md + 80),
                children: [
                  // AI Coach
                  _SectionLabel(label: 'AI Coach'),
                  const SizedBox(height: LumioSpacing.sm),
                  const PersonaSelectionWidget(),
                  const SizedBox(height: LumioSpacing.sm),

                  // Avatar
                  Consumer<GrowthProvider>(
                    builder: (context, provider, _) => _LumioCard(
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: LumioSpacing.md),
                            title: Text('Use Avatar as Profile Picture', style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textPrimary(context), fontWeight: FontWeight.w600)),
                            subtitle: Text('Show your customized avatar in the app', style: LumioTypography.bodySmall.copyWith(color: LumioColors.textSecondary(context))),
                            value: provider.showAvatarInProfile,
                            onChanged: (val) => provider.toggleProfileImageSource(val),
                            activeColor: LumioColors.primary,
                          ),
                          if (provider.showAvatarInProfile) ...[
                            Divider(height: 1, color: LumioColors.border(context)),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: LumioSpacing.md),
                              leading: const Icon(Icons.edit_rounded, color: LumioColors.primary),
                              title: Text('Customize Avatar', style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textPrimary(context), fontWeight: FontWeight.w600)),
                              trailing: Icon(Icons.chevron_right_rounded, color: LumioColors.textSecondary(context)),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AvatarEditorScreen())),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: LumioSpacing.lg),

                  // Appearance
                  _SectionLabel(label: 'Appearance'),
                  const SizedBox(height: LumioSpacing.sm),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) => _LumioCard(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: LumioSpacing.md),
                        leading: Icon(_getThemeIcon(themeProvider.themeMode), color: LumioColors.textPrimary(context)),
                        title: Text('App Theme', style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textPrimary(context), fontWeight: FontWeight.w600)),
                        subtitle: Text(_getThemeModeName(themeProvider.themeMode), style: LumioTypography.bodySmall.copyWith(color: LumioColors.textSecondary(context))),
                        trailing: Icon(Icons.chevron_right_rounded, color: LumioColors.textSecondary(context)),
                        onTap: () => _showThemeDialog(context, themeProvider),
                      ),
                    ),
                  ),
                  const SizedBox(height: LumioSpacing.lg),

                  // Notifications
                  _SectionLabel(label: 'Notifications'),
                  const SizedBox(height: LumioSpacing.sm),
                  _LumioCard(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: LumioSpacing.md),
                      leading: Icon(Icons.notifications_rounded, color: LumioColors.textPrimary(context)),
                      title: Text('Notification Settings', style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textPrimary(context), fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        _notificationsEnabled ? 'Notifications are enabled' : 'Tap to enable notifications',
                        style: LumioTypography.bodySmall.copyWith(color: _notificationsEnabled ? LumioColors.success : LumioColors.textSecondary(context)),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: LumioColors.textSecondary(context)),
                      onTap: () async {
                        final granted = await _permissionService.ensureNotificationPermission(context, rationale: 'Notifications are required to deliver reminders.');
                        if (granted && mounted) _refreshStatuses();
                      },
                    ),
                  ),
                  const SizedBox(height: LumioSpacing.lg),

                  // Permissions
                  _SectionLabel(label: 'Permissions'),
                  const SizedBox(height: LumioSpacing.sm),
                  _LumioCard(
                    child: Column(
                      children: [
                        _PermissionTile(
                          context: context,
                          icon: Icons.schedule_rounded,
                          label: 'Exact Alarms',
                          subtitle: _exactAlarmEnabled ? 'Enabled for precise reminders' : 'Disabled — reminders may be delayed',
                          enabled: _exactAlarmEnabled,
                          onManage: () async {
                            final granted = await _permissionService.ensureExactAlarmPermission(context, rationale: 'Exact alarms are needed for precise reminder delivery.');
                            if (granted && mounted) _refreshStatuses();
                          },
                        ),
                        Divider(height: 1, color: LumioColors.border(context)),
                        _PermissionTile(
                          context: context,
                          icon: Icons.mic_rounded,
                          label: 'Microphone',
                          subtitle: _microphoneEnabled ? 'Enabled for voice input' : 'Disabled',
                          enabled: _microphoneEnabled,
                          onManage: () async {
                            final granted = await _permissionService.ensureMicrophonePermission(context, rationale: 'Microphone is needed for voice input when creating reminders.');
                            if (granted && mounted) _refreshStatuses();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LumioSpacing.lg),

                  // App Settings
                  _SectionLabel(label: 'App Settings'),
                  const SizedBox(height: LumioSpacing.sm),
                  _LumioCard(
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: LumioSpacing.md),
                          leading: Icon(Icons.settings_applications_rounded, color: LumioColors.textPrimary(context)),
                          title: Text('System Settings', style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textPrimary(context), fontWeight: FontWeight.w600)),
                          subtitle: Text('Open device settings', style: LumioTypography.bodySmall.copyWith(color: LumioColors.textSecondary(context))),
                          trailing: Icon(Icons.open_in_new_rounded, size: 18, color: LumioColors.textSecondary(context)),
                          onTap: () => _permissionService.openSettings(),
                        ),
                        Divider(height: 1, color: LumioColors.border(context)),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: LumioSpacing.md),
                          leading: Icon(Icons.storage_rounded, color: LumioColors.textPrimary(context)),
                          title: Text('Data & Storage', style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textPrimary(context), fontWeight: FontWeight.w600)),
                          subtitle: Text('Manage app data and cache', style: LumioTypography.bodySmall.copyWith(color: LumioColors.textSecondary(context))),
                          trailing: Icon(Icons.chevron_right_rounded, color: LumioColors.textSecondary(context)),
                          onTap: () => _showDataManagementDialog(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LumioSpacing.lg),

                  // About
                  _SectionLabel(label: 'About'),
                  const SizedBox(height: LumioSpacing.sm),
                  _LumioCard(
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: LumioSpacing.md),
                          leading: Icon(Icons.info_outline_rounded, color: LumioColors.textPrimary(context)),
                          title: Text('App Version', style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textPrimary(context), fontWeight: FontWeight.w600)),
                          subtitle: Text('1.0.0', style: LumioTypography.bodySmall.copyWith(color: LumioColors.textSecondary(context))),
                        ),
                        Divider(height: 1, color: LumioColors.border(context)),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: LumioSpacing.md),
                          leading: Icon(Icons.description_rounded, color: LumioColors.textPrimary(context)),
                          title: Text('Privacy Policy', style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textPrimary(context), fontWeight: FontWeight.w600)),
                          trailing: Icon(Icons.open_in_new_rounded, size: 18, color: LumioColors.textSecondary(context)),
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Privacy policy coming soon'))),
                        ),
                        Divider(height: 1, color: LumioColors.border(context)),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: LumioSpacing.md),
                          leading: Icon(Icons.description_rounded, color: LumioColors.textPrimary(context)),
                          title: Text('Terms of Service', style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textPrimary(context), fontWeight: FontWeight.w600)),
                          trailing: Icon(Icons.open_in_new_rounded, size: 18, color: LumioColors.textSecondary(context)),
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terms of service coming soon'))),
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
      builder: (_) => AlertDialog(
        backgroundColor: LumioColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: LumioRadius.card),
        title: Text('Data & Storage', style: LumioTypography.titleMedium.copyWith(color: LumioColors.textPrimary(context))),
        content: Text('Data management features coming soon. You can clear app data from system settings.', style: TextStyle(color: LumioColors.textSecondary(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          TextButton(onPressed: () { Navigator.pop(context); _permissionService.openSettings(); }, child: const Text('Open Settings')),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: LumioColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: LumioRadius.card),
        title: Text('Choose Theme', style: LumioTypography.titleMedium.copyWith(color: LumioColors.textPrimary(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _themeOption(context, themeProvider, ThemeMode.light, 'Light Mode', Icons.light_mode_rounded),
            _themeOption(context, themeProvider, ThemeMode.dark, 'Dark Mode', Icons.dark_mode_rounded),
            _themeOption(context, themeProvider, ThemeMode.system, 'System Default', Icons.settings_brightness_rounded),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
      ),
    );
  }

  Widget _themeOption(BuildContext context, ThemeProvider provider, ThemeMode mode, String label, IconData icon) {
    return RadioListTile<ThemeMode>(
      value: mode,
      groupValue: provider.themeMode,
      onChanged: (v) { if (v != null) { provider.setThemeMode(v); Navigator.pop(context); } },
      title: Text(label, style: TextStyle(color: LumioColors.textPrimary(context))),
      secondary: Icon(icon, color: provider.themeMode == mode ? LumioColors.primary : LumioColors.textSecondary(context)),
      activeColor: LumioColors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'Light Mode';
      case ThemeMode.dark: return 'Dark Mode';
      case ThemeMode.system: return 'System Default';
    }
  }

  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return Icons.light_mode_rounded;
      case ThemeMode.dark: return Icons.dark_mode_rounded;
      case ThemeMode.system: return Icons.settings_brightness_rounded;
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: LumioTypography.labelSmall.copyWith(
        color: LumioColors.textSecondary(context),
        letterSpacing: 1.0,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LumioCard extends StatelessWidget {
  final Widget child;
  const _LumioCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LumioColors.surface(context),
        borderRadius: LumioRadius.card,
        boxShadow: LumioShadows.getSoft(context),
      ),
      child: child,
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final BuildContext context;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool enabled;
  final VoidCallback onManage;

  const _PermissionTile({
    required this.context,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.enabled,
    required this.onManage,
  });

  @override
  Widget build(BuildContext ctx) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: LumioSpacing.md),
      leading: Icon(icon, color: LumioColors.textPrimary(context)),
      title: Text(label, style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textPrimary(context), fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: LumioTypography.bodySmall.copyWith(color: enabled ? LumioColors.success : LumioColors.textSecondary(context))),
      trailing: GestureDetector(
        onTap: onManage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: LumioColors.border(context)),
            borderRadius: LumioRadius.radiusSM,
          ),
          child: Text('Manage', style: LumioTypography.labelSmall.copyWith(color: LumioColors.textPrimary(context), fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
