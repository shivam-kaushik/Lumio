import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/auth_provider.dart' as app_auth;
import '../theme/app_theme.dart';
import '../widgets/modern_smart_card.dart';
import '../../core/services/premium_service.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'recent_notifications_screen.dart';
import 'premium_subscription_screen.dart';
import '../providers/growth_provider.dart'; // NEW
import '../widgets/avatar_widget.dart'; // NEW
import 'avatar_editor_screen.dart'; // NEW

/// Account screen showing user profile and settings access
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppTheme.backgroundColor,
      body: Consumer<app_auth.AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;

          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 64,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  Text(
                    'Not signed in',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

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
                        'My Account',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_rounded),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                      tooltip: 'Settings',
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                  ],
                ),
              ),

              // Body content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMD,
                    AppTheme.spacingMD,
                    AppTheme.spacingMD,
                    120, // keep above bottom nav bar
                  ),
                  children: [
                    // Profile Card
                    ModernSmartCard(
                      useGradient: true,
                      elevationLevel: 2,
                      child: Column(
                        children: [
                          const SizedBox(height: AppTheme.spacingMD),
                          // Profile Photo
                          // Profile Photo
                          Consumer<GrowthProvider>(
                            builder: (context, growthProvider, _) {
                              final showAvatar = growthProvider.showAvatarInProfile;
                              return Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () => _showProfilePhotoOptions(context, growthProvider),
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppTheme.primaryColor,
                                            AppTheme.primaryLight,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryColor.withOpacity(0.3),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: showAvatar
                                          ? AvatarWidget(config: growthProvider.avatarConfig, size: 100)
                                          : (user.photoURL != null
                                              ? ClipOval(
                                                  child: CachedNetworkImage(
                                                    imageUrl: user.photoURL!,
                                                    fit: BoxFit.cover,
                                                    placeholder: (context, url) => Container(
                                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                                      child: const Center(
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                      ),
                                                    ),
                                                    errorWidget: (context, url, error) => Icon(
                                                      Icons.person_rounded,
                                                      size: 50,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.person_rounded,
                                                  size: 50,
                                                  color: Colors.white,
                                                )),
                                    ),
                                  ),
                                  // Edit Icon Badge
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () => _showProfilePhotoOptions(context, growthProvider),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppTheme.primaryColor,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.edit_rounded,
                                          size: 18,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: AppTheme.spacingLG),
                          
                          // User Name
                          Text(
                            user.displayName ?? 'User',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingXS),
                          
                          // Email
                          Text(
                            user.email ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingSM),
                          
                          // Premium Status Badge
                          FutureBuilder<bool>(
                            future: PremiumService().isPremium(),
                            builder: (context, snapshot) {
                              final isPremium = snapshot.data ?? false;
                              
                              if (isPremium) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingMD,
                                    vertical: AppTheme.spacingXS,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                                    border: Border.all(
                                      color: Colors.amber.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: AppTheme.spacingXS),
                                      Text(
                                        'Premium Member',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.amber.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // Not Premium - Show Upgrade Button
                              return InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const PremiumSubscriptionScreen(),
                                    ),
                                  ).then((_) => setState(() {})); // Refresh state on return
                                },
                                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingMD,
                                    vertical: AppTheme.spacingXS,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.primaryColor,
                                        AppTheme.primaryColor.withBlue(200),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.auto_awesome,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: AppTheme.spacingXS),
                                      Text(
                                        'Upgrade to Premium',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),

                    // Account Info Section
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                      child: Text(
                        'Account Information',
                        style: theme.textTheme.titleMedium?.copyWith(
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
                          _InfoTile(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: user.email ?? 'Not available',
                            isDark: isDark,
                          ),
                          Divider(
                            height: 1,
                            color: isDark
                                ? AppTheme.darkDivider
                                : AppTheme.dividerColor,
                          ),
                          _InfoTile(
                            icon: Icons.person_outline_rounded,
                            label: 'Display Name',
                            value: user.displayName ?? 'Not set',
                            isDark: isDark,
                          ),
                          Divider(
                            height: 1,
                            color: isDark
                                ? AppTheme.darkDivider
                                : AppTheme.dividerColor,
                          ),
                          _InfoTile(
                            icon: Icons.calendar_today_outlined,
                            label: 'Member Since',
                            value: user.metadata.creationTime != null
                                ? _formatDate(user.metadata.creationTime!)
                                : 'Unknown',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),

                    // Quick Actions
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                      child: Text(
                        'Quick Actions',
                        style: theme.textTheme.titleMedium?.copyWith(
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
                              Icons.notifications_active_rounded,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                            ),
                            title: Text(
                              'Notification History',
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'View past alerts and nudges',
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
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const RecentNotificationsScreen(),
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
                              Icons.settings_rounded,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                            ),
                            title: Text(
                              'Settings',
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'App preferences and permissions',
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
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const SettingsScreen(),
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
                              Icons.logout_rounded,
                              color: AppTheme.errorColor,
                            ),
                            title: Text(
                              'Sign Out',
                              style: TextStyle(
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Sign out of your account',
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => _showSignOutDialog(context, authProvider),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _showSignOutDialog(
    BuildContext context,
    app_auth.AuthProvider authProvider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await authProvider.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );
      }
    }
  // ... existing code ...
  }
  
  void _showProfilePhotoOptions(BuildContext context, GrowthProvider growthProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkSurface 
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Profile Picture",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            
            // Option 1: Use Google Account Photo
            ListTile(
              leading: const Icon(Icons.account_circle_rounded, color: Colors.blue),
              title: const Text("Use Google Account Photo"),
              trailing: !growthProvider.showAvatarInProfile 
                  ? const Icon(Icons.check_circle, color: AppTheme.successColor) 
                  : null,
              onTap: () {
                growthProvider.toggleProfileImageSource(false); // Disable avatar
                Navigator.pop(context);
              },
            ),
            
            // Option 2: Use App Avatar
            ListTile(
              leading: const Icon(Icons.face_rounded, color: Colors.orange),
              title: const Text("Use Gamified Avatar"),
              trailing: growthProvider.showAvatarInProfile 
                  ? const Icon(Icons.check_circle, color: AppTheme.successColor) 
                  : null,
              onTap: () {
                growthProvider.toggleProfileImageSource(true); // Enable avatar
                Navigator.pop(context);
              },
            ),
            
            // Option 3: Customize Avatar
             ListTile(
              leading: const Icon(Icons.edit, color: Colors.purple),
              title: const Text("Customize Avatar"),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context); // Close sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const AvatarEditorScreen()),
                );
              },
            ),
             const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Info tile widget for displaying account information
class _InfoTile extends StatelessWidget {
// ... existing code ...
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        size: 20,
        color: isDark
            ? AppTheme.darkTextSecondary
            : AppTheme.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDark
              ? AppTheme.darkTextSecondary
              : AppTheme.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          color: isDark
              ? AppTheme.darkTextPrimary
              : AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
