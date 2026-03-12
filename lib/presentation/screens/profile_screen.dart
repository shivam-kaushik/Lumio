import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/auth_provider.dart' as app_auth;
import '../providers/growth_provider.dart';
import '../theme/theme.dart';
import '../../core/services/premium_service.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'recent_notifications_screen.dart';
import 'premium_subscription_screen.dart';
import '../widgets/avatar_widget.dart';
import 'avatar_editor_screen.dart';

/// Profile screen based on Stitch AI mockup
/// Features: Stats grid, productivity trends, badges, settings menu
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LumioColors.background(context),
      body: Consumer<app_auth.AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;

          if (user == null) {
            return _buildNotSignedIn(context);
          }

          return CustomScrollView(
            slivers: [
              // Sticky Header
              _buildStickyHeader(context),

              // Main Content
              SliverPadding(
                padding: EdgeInsets.only(
                  left: LumioSpacing.screenHorizontal,
                  right: LumioSpacing.screenHorizontal,
                  bottom: 120,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Profile Card
                    _buildProfileCard(context, user),
                    SizedBox(height: LumioSpacing.lg),

                    // Stats Grid
                    _buildStatsGrid(context),
                    SizedBox(height: LumioSpacing.lg),

                    // Productivity Trends
                    _buildProductivityTrends(context),
                    SizedBox(height: LumioSpacing.lg),

                    // Badges Section
                    _buildBadgesSection(context),
                    SizedBox(height: LumioSpacing.lg),

                    // Settings Menu
                    _buildSettingsMenu(context, authProvider),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotSignedIn(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 64,
            color: LumioColors.textTertiary(context),
          ),
          SizedBox(height: LumioSpacing.md),
          Text(
            'Not signed in',
            style: LumioTypography.titleLarge.copyWith(
              color: LumioColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyHeader(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: LumioColors.background(context).withOpacity(0.9),
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        'Profile',
        style: LumioTypography.titleLarge.copyWith(
          color: LumioColors.textPrimary(context),
        ),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: Icon(
            Icons.settings_outlined,
            color: LumioColors.textPrimary(context),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context, User user) {
    return Container(
      padding: LumioSpacing.cardPaddingLarge,
      decoration: BoxDecoration(
        gradient: LumioColors.profileGradient(context),
        borderRadius: LumioRadius.radiusXXXL,
        boxShadow: LumioShadows.getSoft(context),
      ),
      child: Column(
        children: [
          // Avatar with verified badge
          Consumer<GrowthProvider>(
            builder: (context, growthProvider, _) {
              return GestureDetector(
                onTap: () => _showProfilePhotoOptions(context, growthProvider),
                child: Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: LumioColors.surface(context),
                          width: 4,
                        ),
                        boxShadow: LumioShadows.getMedium(context),
                      ),
                      child: ClipOval(
                        child: growthProvider.showAvatarInProfile
                            ? AvatarWidget(
                                config: growthProvider.avatarConfig,
                                size: 96,
                              )
                            : (user.photoURL != null
                                ? CachedNetworkImage(
                                    imageUrl: user.photoURL!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: LumioColors.primaryLight,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: LumioColors.primary,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: LumioColors.primaryLight,
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 48,
                                        color: LumioColors.primary,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: LumioColors.primaryLight,
                                    child: Icon(
                                      Icons.person_rounded,
                                      size: 48,
                                      color: LumioColors.primary,
                                    ),
                                  )),
                      ),
                    ),
                    // Verified badge
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: LumioColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: LumioColors.surface(context),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: LumioSpacing.md),

          // Name
          Text(
            user.displayName ?? 'User',
            style: LumioTypography.headlineMedium.copyWith(
              color: LumioColors.textPrimary(context),
            ),
          ),
          SizedBox(height: LumioSpacing.sm),

          // Premium Badge
          FutureBuilder<bool>(
            future: PremiumService().isPremium(),
            builder: (context, snapshot) {
              final isPremium = snapshot.data ?? false;

              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: LumioSpacing.md,
                  vertical: LumioSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isPremium
                      ? LumioColors.primary.withOpacity(0.2)
                      : LumioColors.primaryLight,
                  borderRadius: LumioRadius.radiusFull,
                ),
                child: Text(
                  isPremium ? 'LUMIO PREMIUM' : 'FREE PLAN',
                  style: LumioTypography.premiumBadge.copyWith(
                    color: LumioColors.primary,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: LumioSpacing.md),

          // Bio
          Text(
            user.email ?? '',
            style: LumioTypography.bodyMedium.copyWith(
              color: LumioColors.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return Consumer<GrowthProvider>(
      builder: (context, growthProvider, _) {
        final stats = growthProvider.userStats;
        final streak = stats?.streak ?? 0;
        final level = stats?.level ?? 1;
        final tasksCompleted = growthProvider.allTasks.where((t) => t.isCompleted).length;

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.local_fire_department_rounded,
                value: streak.toString(),
                label: 'Day Streak',
              ),
            ),
            SizedBox(width: LumioSpacing.md),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.emoji_events_rounded,
                value: 'Lv.$level',
                label: 'Level',
              ),
            ),
            SizedBox(width: LumioSpacing.md),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.check_circle_outline_rounded,
                value: tasksCompleted.toString(),
                label: 'Tasks Done',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      height: 128,
      padding: LumioSpacing.paddingMD,
      decoration: BoxDecoration(
        color: LumioColors.surface(context),
        borderRadius: LumioRadius.radiusXXL,
        boxShadow: LumioShadows.getSoft(context),
        border: Border.all(
          color: LumioColors.border(context).withOpacity(0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: LumioColors.primary, size: 24),
          SizedBox(height: LumioSpacing.sm),
          Text(
            value,
            style: LumioTypography.statsNumber.copyWith(
              color: LumioColors.textPrimary(context),
            ),
          ),
          SizedBox(height: LumioSpacing.xs),
          Text(
            label,
            style: LumioTypography.statsLabel.copyWith(
              color: LumioColors.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductivityTrends(BuildContext context) {
    return Container(
      padding: LumioSpacing.cardPadding,
      decoration: BoxDecoration(
        color: LumioColors.surface(context),
        borderRadius: LumioRadius.radiusXXL,
        boxShadow: LumioShadows.getSoft(context),
        border: Border.all(
          color: LumioColors.border(context).withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Productivity Trends',
                style: LumioTypography.titleMedium.copyWith(
                  color: LumioColors.textPrimary(context),
                ),
              ),
              Text(
                'This Week',
                style: LumioTypography.bodySmall.copyWith(
                  color: LumioColors.textSecondary(context),
                ),
              ),
            ],
          ),
          SizedBox(height: LumioSpacing.xl),

          // Bar chart
          SizedBox(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(context, 'M', 0.3, false),
                _buildBar(context, 'T', 0.5, false),
                _buildBar(context, 'W', 0.7, false),
                _buildBar(context, 'T', 0.9, true), // Today
                _buildBar(context, 'F', 0.4, false),
                _buildBar(context, 'S', 0.2, false),
                _buildBar(context, 'S', 0.35, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context, String label, double fill, bool isToday) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 8,
              height: fill * 80,
              decoration: BoxDecoration(
                color: isToday
                    ? LumioColors.primary
                    : LumioColors.primary.withOpacity(0.3),
                borderRadius: LumioRadius.radiusFull,
                boxShadow: isToday ? LumioShadows.progressHighlight : null,
              ),
            ),
          ),
        ),
        SizedBox(height: LumioSpacing.sm),
        Text(
          label,
          style: LumioTypography.labelSmall.copyWith(
            color: isToday
                ? LumioColors.primary
                : LumioColors.textSecondary(context),
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgesSection(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Badges',
              style: LumioTypography.titleMedium.copyWith(
                color: LumioColors.textPrimary(context),
              ),
            ),
            GestureDetector(
              onTap: () {
                // TODO: View all badges
              },
              child: Text(
                'View All',
                style: LumioTypography.bodyMedium.copyWith(
                  color: LumioColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: LumioSpacing.md),

        // Badges row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildBadge(context, Icons.emoji_events_rounded, true),
              SizedBox(width: LumioSpacing.md),
              _buildBadge(context, Icons.bolt_rounded, true),
              SizedBox(width: LumioSpacing.md),
              _buildBadge(context, Icons.psychology_rounded, true),
              SizedBox(width: LumioSpacing.md),
              _buildBadge(context, Icons.lock_outline_rounded, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(BuildContext context, IconData icon, bool unlocked) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked
            ? LumioColors.primaryLight
            : LumioColors.border(context).withOpacity(0.3),
        border: Border.all(
          color: unlocked
              ? LumioColors.primary.withOpacity(0.3)
              : LumioColors.border(context),
          width: 2,
          style: unlocked ? BorderStyle.solid : BorderStyle.none,
        ),
      ),
      child: Icon(
        icon,
        size: 32,
        color: unlocked ? LumioColors.primary : LumioColors.textTertiary(context),
      ),
    );
  }

  Widget _buildSettingsMenu(BuildContext context, app_auth.AuthProvider authProvider) {
    return Column(
      children: [
        _buildSettingsItem(
          context,
          icon: Icons.person_outline_rounded,
          title: 'Account Details',
          onTap: () {
            // TODO: Account details
          },
        ),
        SizedBox(height: LumioSpacing.md),
        _buildSettingsItem(
          context,
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecentNotificationsScreen()),
            );
          },
        ),
        SizedBox(height: LumioSpacing.md),
        _buildSettingsItem(
          context,
          icon: Icons.tune_rounded,
          title: 'Preferences',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        SizedBox(height: LumioSpacing.xl),

        // Sign out button
        GestureDetector(
          onTap: () => _showSignOutDialog(context, authProvider),
          child: Container(
            width: double.infinity,
            padding: LumioSpacing.paddingMD,
            decoration: BoxDecoration(
              color: LumioColors.error.withOpacity(0.1),
              borderRadius: LumioRadius.radiusLG,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: LumioColors.error, size: 20),
                SizedBox(width: LumioSpacing.sm),
                Text(
                  'Sign Out',
                  style: LumioTypography.labelLarge.copyWith(
                    color: LumioColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: LumioSpacing.paddingMD,
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: LumioRadius.radiusXXL,
          boxShadow: LumioShadows.getSoft(context),
          border: Border.all(
            color: LumioColors.border(context).withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: LumioColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: LumioColors.primary, size: 20),
            ),
            SizedBox(width: LumioSpacing.md),
            Expanded(
              child: Text(
                title,
                style: LumioTypography.titleMedium.copyWith(
                  color: LumioColors.textPrimary(context),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: LumioColors.textTertiary(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfilePhotoOptions(BuildContext context, GrowthProvider growthProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: LumioRadius.bottomSheet,
        ),
        padding: LumioSpacing.paddingLG,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LumioColors.border(context),
                  borderRadius: LumioRadius.radiusFull,
                ),
              ),
            ),
            SizedBox(height: LumioSpacing.lg),
            Text(
              'Profile Picture',
              style: LumioTypography.headlineSmall.copyWith(
                color: LumioColors.textPrimary(context),
              ),
            ),
            SizedBox(height: LumioSpacing.lg),

            ListTile(
              leading: Icon(Icons.account_circle_rounded, color: LumioColors.info),
              title: Text('Use Google Account Photo'),
              trailing: !growthProvider.showAvatarInProfile
                  ? Icon(Icons.check_circle, color: LumioColors.success)
                  : null,
              onTap: () {
                growthProvider.toggleProfileImageSource(false);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.face_rounded, color: LumioColors.primary),
              title: Text('Use Gamified Avatar'),
              trailing: growthProvider.showAvatarInProfile
                  ? Icon(Icons.check_circle, color: LumioColors.success)
                  : null,
              onTap: () {
                growthProvider.toggleProfileImageSource(true);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: LumioColors.categoryPersonal),
              title: Text('Customize Avatar'),
              trailing: Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AvatarEditorScreen()),
                );
              },
            ),
            SizedBox(height: LumioSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _showSignOutDialog(
    BuildContext context,
    app_auth.AuthProvider authProvider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LumioColors.error,
            ),
            child: Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await authProvider.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
