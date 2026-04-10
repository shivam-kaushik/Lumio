import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/auth_provider.dart' as app_auth;
import '../theme/theme.dart';
import '../../core/services/premium_service.dart';
import 'settings_screen.dart';
import 'recent_notifications_screen.dart';
import 'premium_subscription_screen.dart';
import '../providers/growth_provider.dart';
import '../widgets/avatar_widget.dart';
import 'avatar_editor_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LumioColors.background(context),
      body: Consumer<app_auth.AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;
          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline_rounded, size: 64, color: LumioColors.textSecondary(context)),
                  const SizedBox(height: LumioSpacing.md),
                  Text('Not signed in', style: LumioTypography.titleMedium.copyWith(color: LumioColors.textSecondary(context))),
                ],
              ),
            );
          }
          return Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(LumioSpacing.md, LumioSpacing.md, LumioSpacing.md, LumioSpacing.md + 80),
                  children: [
                    _buildProfileCard(context, user, authProvider),
                    const SizedBox(height: LumioSpacing.lg),
                    _buildSectionLabel(context, 'Account Information'),
                    const SizedBox(height: LumioSpacing.sm),
                    _buildAccountInfoCard(context, user, authProvider),
                    const SizedBox(height: LumioSpacing.lg),
                    _buildSectionLabel(context, 'Quick Actions'),
                    const SizedBox(height: LumioSpacing.sm),
                    _buildActionsCard(context, authProvider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + LumioSpacing.sm,
        left: LumioSpacing.lg,
        right: LumioSpacing.sm,
        bottom: LumioSpacing.md,
      ),
      decoration: BoxDecoration(
        color: LumioColors.background(context),
        border: Border(bottom: BorderSide(color: LumioColors.border(context), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(child: Text('My Account', style: LumioTypography.headlineSmall.copyWith(color: LumioColors.textPrimary(context)))),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            color: LumioColors.textPrimary(context),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, User user, app_auth.AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(LumioSpacing.lg),
      decoration: BoxDecoration(
        color: LumioColors.surface(context),
        borderRadius: LumioRadius.card,
        boxShadow: LumioShadows.getSoft(context),
      ),
      child: Column(
        children: [
          Consumer<GrowthProvider>(
            builder: (context, growthProvider, _) {
              final showAvatar = growthProvider.showAvatarInProfile;
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () => _showProfilePhotoOptions(context, growthProvider),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [LumioColors.primary, LumioColors.primaryHover],
                        ),
                        boxShadow: [BoxShadow(color: LumioColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: showAvatar
                          ? AvatarWidget(config: growthProvider.avatarConfig, size: 96)
                          : (user.photoURL != null
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: user.photoURL!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: LumioColors.primaryLight, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                                    errorWidget: (_, __, ___) => const Icon(Icons.person_rounded, size: 48, color: Colors.white),
                                  ),
                                )
                              : const Icon(Icons.person_rounded, size: 48, color: Colors.white)),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _showProfilePhotoOptions(context, growthProvider),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: LumioColors.surface(context),
                          shape: BoxShape.circle,
                          border: Border.all(color: LumioColors.primary, width: 2),
                          boxShadow: LumioShadows.getSoft(context),
                        ),
                        child: const Icon(Icons.edit_rounded, size: 14, color: LumioColors.primary),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: LumioSpacing.md),
          Text(
            user.displayName ?? 'User',
            style: LumioTypography.headlineSmall.copyWith(color: LumioColors.textPrimary(context)),
          ),
          const SizedBox(height: LumioSpacing.xs),
          Text(user.email ?? '', style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textSecondary(context))),
          const SizedBox(height: LumioSpacing.sm),
          FutureBuilder<bool>(
            future: PremiumService().isPremium(),
            builder: (context, snapshot) {
              final isPremium = snapshot.data ?? false;
              if (isPremium) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: LumioSpacing.md, vertical: LumioSpacing.xs),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: LumioRadius.chip,
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                      const SizedBox(width: LumioSpacing.xs),
                      Text('Premium Member', style: LumioTypography.labelSmall.copyWith(color: Colors.amber.shade700, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }
              return GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumSubscriptionScreen())).then((_) => setState(() {})),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: LumioSpacing.md, vertical: LumioSpacing.xs),
                  decoration: BoxDecoration(
                    color: LumioColors.primary,
                    borderRadius: LumioRadius.chip,
                    boxShadow: [BoxShadow(color: LumioColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                      const SizedBox(width: LumioSpacing.xs),
                      const Text('Upgrade to Premium', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: LumioTypography.labelMedium.copyWith(
        color: LumioColors.textSecondary(context),
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildAccountInfoCard(BuildContext context, User user, app_auth.AuthProvider authProvider) {
    return Container(
      decoration: BoxDecoration(
        color: LumioColors.surface(context),
        borderRadius: LumioRadius.card,
        boxShadow: LumioShadows.getSoft(context),
      ),
      child: Column(
        children: [
          _InfoRow(
            context: context,
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email ?? 'Not available',
          ),
          Divider(height: 1, color: LumioColors.border(context)),
          _InfoRow(
            context: context,
            icon: Icons.person_outline_rounded,
            label: 'Display Name',
            value: user.displayName ?? 'Not set',
            onEdit: () => _showEditNameDialog(context, user, authProvider),
          ),
          Divider(height: 1, color: LumioColors.border(context)),
          _InfoRow(
            context: context,
            icon: Icons.calendar_today_outlined,
            label: 'Member Since',
            value: user.metadata.creationTime != null ? _formatDate(user.metadata.creationTime!) : 'Unknown',
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, app_auth.AuthProvider authProvider) {
    return Container(
      decoration: BoxDecoration(
        color: LumioColors.surface(context),
        borderRadius: LumioRadius.card,
        boxShadow: LumioShadows.getSoft(context),
      ),
      child: Column(
        children: [
          _ActionTile(
            context: context,
            icon: Icons.notifications_active_rounded,
            label: 'Notification History',
            subtitle: 'View past alerts and nudges',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecentNotificationsScreen())),
          ),
          Divider(height: 1, color: LumioColors.border(context)),
          _ActionTile(
            context: context,
            icon: Icons.settings_rounded,
            label: 'Settings',
            subtitle: 'App preferences and permissions',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          Divider(height: 1, color: LumioColors.border(context)),
          _ActionTile(
            context: context,
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            subtitle: 'Sign out of your account',
            iconColor: LumioColors.error,
            labelColor: LumioColors.error,
            onTap: () => _showSignOutDialog(context, authProvider),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog(BuildContext context, User user, app_auth.AuthProvider authProvider) async {
    final controller = TextEditingController(text: user.displayName ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LumioColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: LumioRadius.card),
        title: Text('Edit Display Name', style: LumioTypography.titleMedium.copyWith(color: LumioColors.textPrimary(context))),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: LumioColors.textSecondary(context)),
            border: OutlineInputBorder(borderRadius: LumioRadius.input, borderSide: BorderSide(color: LumioColors.border(context))),
            focusedBorder: OutlineInputBorder(borderRadius: LumioRadius.input, borderSide: const BorderSide(color: LumioColors.primary, width: 2)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: LumioColors.textSecondary(context)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: LumioColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: LumioRadius.button)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        await user.updateDisplayName(controller.text.trim());
        await user.reload();
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update name: $e'), backgroundColor: LumioColors.error));
        }
      }
    }
    controller.dispose();
  }

  Future<void> _showSignOutDialog(BuildContext context, app_auth.AuthProvider authProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LumioColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: LumioRadius.card),
        title: Text('Sign Out', style: LumioTypography.titleMedium.copyWith(color: LumioColors.textPrimary(context))),
        content: Text('Are you sure you want to sign out?', style: TextStyle(color: LumioColors.textSecondary(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: LumioColors.textSecondary(context)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: LumioColors.error, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: LumioRadius.button)),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await authProvider.signOut();
      // AuthGate handles routing reactively — no manual navigation needed
    }
  }

  void _showProfilePhotoOptions(BuildContext context, GrowthProvider growthProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(LumioSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile Picture', style: LumioTypography.titleLarge.copyWith(color: LumioColors.textPrimary(context))),
            const SizedBox(height: LumioSpacing.lg),
            ListTile(
              leading: const Icon(Icons.account_circle_rounded, color: Colors.blue),
              title: Text('Use Google Account Photo', style: TextStyle(color: LumioColors.textPrimary(context))),
              trailing: !growthProvider.showAvatarInProfile ? const Icon(Icons.check_circle, color: LumioColors.success) : null,
              onTap: () { growthProvider.toggleProfileImageSource(false); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.face_rounded, color: Colors.orange),
              title: Text('Use Gamified Avatar', style: TextStyle(color: LumioColors.textPrimary(context))),
              trailing: growthProvider.showAvatarInProfile ? const Icon(Icons.check_circle, color: LumioColors.success) : null,
              onTap: () { growthProvider.toggleProfileImageSource(true); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: LumioColors.primary),
              title: Text('Customize Avatar', style: TextStyle(color: LumioColors.textPrimary(context))),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AvatarEditorScreen()));
              },
            ),
            const SizedBox(height: LumioSpacing.md),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final BuildContext context;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onEdit;

  const _InfoRow({
    required this.context,
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
  });

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LumioSpacing.md, vertical: LumioSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: LumioColors.textSecondary(context)),
          const SizedBox(width: LumioSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: LumioTypography.labelSmall.copyWith(color: LumioColors.textSecondary(context))),
                const SizedBox(height: 2),
                Text(value, style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textPrimary(context), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: LumioColors.primary,
              onPressed: onEdit,
              tooltip: 'Edit',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final BuildContext context;
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _ActionTile({
    required this.context,
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext ctx) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: LumioSpacing.md, vertical: LumioSpacing.xs),
      leading: Icon(icon, color: iconColor ?? LumioColors.textPrimary(context)),
      title: Text(label, style: LumioTypography.bodyMedium.copyWith(color: labelColor ?? LumioColors.textPrimary(context), fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: LumioTypography.bodySmall.copyWith(color: LumioColors.textSecondary(context))),
      trailing: Icon(Icons.chevron_right_rounded, color: LumioColors.textSecondary(context)),
      onTap: onTap,
    );
  }
}
