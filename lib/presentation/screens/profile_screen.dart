import 'dart:math' as math;
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
import '../widgets/lumio_main_tab_header.dart';
import 'avatar_editor_screen.dart';
import 'subtasks_calendar_screen.dart';

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
      backgroundColor: LumioColors.background(context).withValues(alpha: 0.95),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        'Profile',
        style: lumioMainTabTitleTextStyle(context),
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: LumioColors.border(context),
        ),
      ),
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
    return Consumer<GrowthProvider>(
      builder: (context, growthProvider, _) {
        final allTasks = growthProvider.allTasks;
        final now = DateTime.now();
        final weekStart = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));

        final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        final dayCounts = List.generate(7, (i) {
          final day = weekStart.add(Duration(days: i));
          return allTasks.where((t) {
            if (!t.isCompleted || t.completedAt == null) return false;
            final cd = DateTime(t.completedAt!.year, t.completedAt!.month, t.completedAt!.day);
            return cd == day;
          }).length.toDouble();
        });

        final maxCount = dayCounts.fold(0.0, math.max);
        final fills = dayCounts.map((c) => maxCount > 0 ? (c / maxCount).clamp(0.1, 1.0) : 0.1).toList();
        final todayIndex = now.weekday - 1; // 0=Mon, 6=Sun

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
              SizedBox(
                height: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final isToday = i == todayIndex;
                    return _buildBar(context, dayLabels[i], fills[i], isToday);
                  }),
                ),
              ),
            ],
          ),
        );
      },
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
    return Consumer<GrowthProvider>(
      builder: (context, growthProvider, _) {
        final stats = growthProvider.userStats;
        final streak = stats?.streak ?? 0;
        final level = stats?.level ?? 1;
        final tasksCompleted = growthProvider.allTasks.where((t) => t.isCompleted).length;
        final completedGoals = growthProvider.goals.where((g) {
          final tasks = growthProvider.getTasksForGoal(g.id);
          if (tasks.isEmpty) return false;
          final done = tasks.where((t) => t.isCompleted).length;
          return done == tasks.length && tasks.isNotEmpty;
        }).length;

        final allBadges = _getBadgeDefinitions(streak, level, tasksCompleted, completedGoals);
        final preview = allBadges.take(4).toList();

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
                  onTap: () => _showAllBadges(context, allBadges),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: preview.asMap().entries.map((e) => Padding(
                  padding: EdgeInsets.only(right: e.key < preview.length - 1 ? LumioSpacing.md : 0),
                  child: _buildBadgeTile(context, e.value),
                )).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _getBadgeDefinitions(int streak, int level, int tasksCompleted, int completedGoals) {
    return [
      {
        'icon': Icons.local_fire_department_rounded,
        'name': 'Streak Master',
        'description': 'Maintain a 7-day streak',
        'color': Colors.orange,
        'unlocked': streak >= 7,
      },
      {
        'icon': Icons.emoji_events_rounded,
        'name': 'Goal Getter',
        'description': 'Complete your first goal',
        'color': Colors.amber,
        'unlocked': completedGoals >= 1,
      },
      {
        'icon': Icons.check_circle_rounded,
        'name': 'Task Champion',
        'description': 'Complete 50 tasks',
        'color': LumioColors.success,
        'unlocked': tasksCompleted >= 50,
      },
      {
        'icon': Icons.psychology_rounded,
        'name': 'Power User',
        'description': 'Reach level 5',
        'color': Colors.purple,
        'unlocked': level >= 5,
      },
      {
        'icon': Icons.bolt_rounded,
        'name': 'Speedster',
        'description': 'Maintain a 3-day streak',
        'color': LumioColors.primary,
        'unlocked': streak >= 3,
      },
      {
        'icon': Icons.star_rounded,
        'name': 'Rising Star',
        'description': 'Complete 10 tasks',
        'color': Colors.blue,
        'unlocked': tasksCompleted >= 10,
      },
    ];
  }

  Widget _buildBadgeTile(BuildContext context, Map<String, dynamic> badge) {
    final unlocked = badge['unlocked'] as bool;
    final color = badge['color'] as Color;

    return GestureDetector(
      onTap: () => _showBadgeDetail(context, badge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? color.withOpacity(0.15) : LumioColors.border(context).withOpacity(0.2),
              border: Border.all(
                color: unlocked ? color.withOpacity(0.5) : LumioColors.border(context),
                width: 2,
              ),
              boxShadow: unlocked ? [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ] : null,
            ),
            child: Icon(
              badge['icon'] as IconData,
              size: 28,
              color: unlocked ? color : LumioColors.textTertiary(context),
            ),
          ),
          SizedBox(height: LumioSpacing.xs),
          SizedBox(
            width: 68,
            child: Text(
              badge['name'] as String,
              style: LumioTypography.labelSmall.copyWith(
                color: unlocked ? LumioColors.textPrimary(context) : LumioColors.textTertiary(context),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showBadgeDetail(BuildContext context, Map<String, dynamic> badge) {
    final unlocked = badge['unlocked'] as bool;
    final color = badge['color'] as Color;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LumioColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unlocked ? color.withOpacity(0.15) : LumioColors.border(context).withOpacity(0.2),
                border: Border.all(color: unlocked ? color.withOpacity(0.5) : LumioColors.border(context), width: 2),
              ),
              child: Icon(badge['icon'] as IconData, size: 36, color: unlocked ? color : LumioColors.textTertiary(context)),
            ),
            SizedBox(height: LumioSpacing.md),
            Text(
              badge['name'] as String,
              style: LumioTypography.titleMedium.copyWith(color: LumioColors.textPrimary(context)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: LumioSpacing.xs),
            Text(
              badge['description'] as String,
              style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textSecondary(context)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: LumioSpacing.md),
            Container(
              padding: EdgeInsets.symmetric(horizontal: LumioSpacing.md, vertical: LumioSpacing.xs),
              decoration: BoxDecoration(
                color: unlocked ? LumioColors.success.withOpacity(0.1) : LumioColors.border(context).withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                unlocked ? 'Unlocked' : 'Locked',
                style: LumioTypography.labelSmall.copyWith(
                  color: unlocked ? LumioColors.success : LumioColors.textSecondary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: LumioSpacing.md),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  void _showAllBadges(BuildContext context, List<Map<String, dynamic>> badges) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(LumioSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('All Badges', style: LumioTypography.titleLarge.copyWith(color: LumioColors.textPrimary(context))),
                  Text('${badges.where((b) => b['unlocked'] as bool).length}/${badges.length}',
                      style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textSecondary(context))),
                ],
              ),
            ),
            Flexible(
              child: GridView.builder(
                padding: EdgeInsets.fromLTRB(LumioSpacing.lg, 0, LumioSpacing.lg, LumioSpacing.xl),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.75,
                ),
                itemCount: badges.length,
                itemBuilder: (_, i) => _buildBadgeTile(context, badges[i]),
              ),
            ),
          ],
        ),
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
          icon: Icons.calendar_today_outlined,
          title: 'My Calendar',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubtasksCalendarScreen()),
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
