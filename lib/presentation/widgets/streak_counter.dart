import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/growth_provider.dart';

class StreakCounter extends StatelessWidget {
  const StreakCounter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GrowthProvider>(
      builder: (context, provider, child) {
        final streak = provider.userStats?.streak ?? 0;
        final level = provider.userStats?.level ?? 1;
        
    return GestureDetector(
      onTap: () => _showGamificationInfo(context, provider),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.orange.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Level
            Text(
              'Lvl $level',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              height: 12,
              width: 1,
              color: Colors.orange.withOpacity(0.5),
            ),
            // Streak
            const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.orange,
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              '$streak',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            // Superscript Info
            Transform.translate(
              offset: const Offset(4, -4),
              child: Icon(
                Icons.help_outline_rounded,
                size: 10,
                color: Colors.orange.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  void _showGamificationInfo(BuildContext context, GrowthProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Your Progress 🚀"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              Icons.star_rounded, 
              "Level ${provider.userStats?.level ?? 1}", 
              "You earn 10 XP for every task. Level up every 100 XP!"
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.local_fire_department_rounded, 
              "${provider.userStats?.streak ?? 0} Day Streak", 
              "Complete at least one task every day to keep your streak alive."
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it!"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.orange, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}
