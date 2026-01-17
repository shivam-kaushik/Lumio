import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/growth_provider.dart';
import '../widgets/avatar_widget.dart';
import '../theme/app_theme.dart';

class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen({super.key});

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  late Map<String, dynamic> _currentConfig;

  @override
  void initState() {
    super.initState();
    // Clone the config to avoid direct mutation
    _currentConfig = Map.from(context.read<GrowthProvider>().avatarConfig);
  }

  void _update(String key, dynamic value) {
    setState(() {
      _currentConfig[key] = value;
    });
  }

  Future<void> _save() async {
    await context.read<GrowthProvider>().updateAvatarConfig(_currentConfig);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Customize Avatar"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 32),
          // Preview
          Center(
            child: AvatarWidget(config: _currentConfig, size: 150),
          ),
          const SizedBox(height: 48),
          
          // Controls
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5),
                ],
              ),
              child: ListView(
                children: [
                  _buildSection("Skin Tone", [
                    _colorOption('skinColor', 0xFFFFDFC4), // Light
                    _colorOption('skinColor', 0xFFF0C0A0), // Tan
                    _colorOption('skinColor', 0xFF8D5524), // Dark
                    _colorOption('skinColor', 0xFFC68642), // Medium
                  ]),
                  
                  const SizedBox(height: 24),
                  
                  _buildSection("Shirt", [
                    _iconOption('shirt', 'tshirt_blue', Icons.checkroom, Colors.blue),
                    _iconOption('shirt', 'tshirt_red', Icons.checkroom, Colors.red),
                    _iconOption('shirt', 'hoodie_grey', Icons.hiking, Colors.grey),
                  ]),

                  const SizedBox(height: 24),
                  
                  _buildSection("Accessories", [
                    _iconOption('accessory', 'none', Icons.close, Colors.grey),
                    _iconOption('accessory', 'glasses', Icons.remove_red_eye_rounded, Colors.indigo),
                    _iconOption('accessory', 'hat', Icons.school, Colors.black),
                    _iconOption('accessory', 'headphones', Icons.headphones, Colors.blueGrey),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: children),
      ],
    );
  }

  Widget _colorOption(String key, int colorValue) {
    final isSelected = _currentConfig[key] == colorValue;
    return GestureDetector(
      onTap: () => _update(key, colorValue),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Color(colorValue),
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.blue, width: 3) : null,
        ),
      ),
    );
  }

  Widget _iconOption(String key, String value, IconData icon, Color color) {
    final isSelected = _currentConfig[key] == value;
    return GestureDetector(
      onTap: () => _update(key, value),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: color, width: 2) : null,
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}
