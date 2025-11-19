import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/auth_provider.dart' as app_auth;
import '../theme/app_theme.dart';
import '../widgets/modern_smart_card.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

/// Account screen showing user profile and settings access
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

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
                          Stack(
                            children: [
                              Container(
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
                                child: user.photoURL != null
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
                                      ),
                              ),
                              // Verified badge for Google accounts
                              if (user.providerData.any(
                                    (info) => info.providerId == 'google.com',
                                  ))
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.primaryColor,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                            ],
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
                          
                          // Account Type Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingMD,
                              vertical: AppTheme.spacingXS,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  user.providerData.any(
                                        (info) => info.providerId == 'google.com',
                                      )
                                      ? Icons.account_circle_rounded
                                      : Icons.email_rounded,
                                  size: 16,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: AppTheme.spacingXS),
                                Text(
                                  user.providerData.any(
                                        (info) => info.providerId == 'google.com',
                                      )
                                      ? 'Google Account'
                                      : 'Email Account',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
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
  }
}

/// Info tile widget for displaying account information
class _InfoTile extends StatelessWidget {
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

