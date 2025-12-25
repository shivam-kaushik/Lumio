import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class MorningHeroCard extends StatelessWidget {
  final VoidCallback onTap;
  final String userName;

  const MorningHeroCard({
    super.key, 
    required this.onTap, 
    this.userName = "User" 
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good Morning! ☀️";
    } else if (hour < 17) {
      return "Good Afternoon! 🌤️";
    } else {
      return "Good Evening! 🌙";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Reduced margin
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6B8EFF), // Soft Blue
            Color(0xFFFF8FB1), // Soft Pink
          ],
        ),
        borderRadius: BorderRadius.circular(20), // Slightly smaller radius
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B8EFF).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            // Reduced padding to make it smaller
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 20),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Start Here",
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20, // Reduced font size
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Ready to design your day?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14, // Reduced font size
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Plan My Day",
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: AppTheme.primaryColor, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate()
     .fadeIn(duration: 600.ms)
     .slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack);
  }
}

class DailySummaryCard extends StatelessWidget {
  final VoidCallback onTap;
  final int completedTasks;
  final int totalTasks;

  const DailySummaryCard({
    super.key,
    required this.onTap,
    required this.completedTasks,
    required this.totalTasks,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
          ? [
            const Color(0xFF1A1A1A),
            const Color(0xFF2C2C2C),
          ]
          : [
             Colors.white,
             const Color(0xFFFFF3E0), // Very pale orange
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: isDark ? null : Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1),
        boxShadow: [
           BoxShadow(
             color: (isDark ? Colors.black : AppTheme.primaryColor).withOpacity(0.15), 
             blurRadius: 15, 
             offset: const Offset(0, 8)
           )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    value: progress,
                    backgroundColor: isDark ? Colors.white24 : AppTheme.primaryColor.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.white : AppTheme.primaryColor
                    ),
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        totalTasks == completedTasks ? "All Done! 🎉" : "Todays Plan",
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$completedTasks of $totalTasks tasks completed",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : AppTheme.textSecondary, 
                          fontSize: 12
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded, 
                  color: isDark ? Colors.white70 : AppTheme.primaryColor, 
                  size: 20
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
