import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';
import '../screens/recent_notifications_screen.dart';

/// Shared padding for tab roots that draw under the status bar (Goals, Calendar).
EdgeInsets lumioMainTabHeaderPadding(BuildContext context) {
  return EdgeInsets.fromLTRB(
    LumioSpacing.screenHorizontal,
    MediaQuery.paddingOf(context).top + LumioSpacing.md,
    LumioSpacing.screenHorizontal,
    LumioSpacing.sm,
  );
}

/// Bottom hairline + slightly opaque background (matches primary scrollable tabs).
Decoration lumioMainTabHeaderDecoration(BuildContext context) {
  return BoxDecoration(
    color: LumioColors.background(context).withValues(alpha: 0.95),
    border: Border(
      bottom: BorderSide(
        color: LumioColors.border(context),
        width: 1,
      ),
    ),
  );
}

TextStyle lumioMainTabTitleTextStyle(BuildContext context) {
  return LumioTypography.headlineSmall.copyWith(
    color: LumioColors.textPrimary(context),
    fontWeight: FontWeight.w700,
  );
}

/// Notification entry used on Home, Goals, and Calendar for consistent Lumio chrome.
class LumioHeaderNotificationButton extends StatelessWidget {
  const LumioHeaderNotificationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const RecentNotificationsScreen(),
          ),
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          shape: BoxShape.circle,
          boxShadow: LumioShadows.getSoft(context),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_outlined,
              color: LumioColors.textPrimary(context),
              size: 22,
            ),
            Positioned(
              top: 8,
              right: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: LumioColors.badge,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: LumioColors.surface(context),
                    width: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
