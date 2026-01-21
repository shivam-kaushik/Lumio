import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttermoji/fluttermoji.dart';
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

  void _updateBgColor(int colorValue) {
    setState(() {
      _currentConfig['backgroundColor'] = colorValue;
    });
  }

  Future<void> _save() async {
    // 1. Save the background color and other custom props to our provider
    await context.read<GrowthProvider>().updateAvatarConfig(_currentConfig);
    
    // 2. FlutterMoji automatically saves selections to local storage, 
    // but we can ensure it's synced if needed.
    // Use FluttermojiFunctions().encodeOptions() if we wanted to save the string to backend.
    
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
          const SizedBox(height: 16),
          // Preview with Background Color
          Center(
            child: AvatarWidget(config: _currentConfig, size: 140),
          ),
          const SizedBox(height: 24),
          
          // Background Color Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text("Background: ", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                _colorOption(0xFFE0F7FA), // Cyan
                const SizedBox(width: 8),
                _colorOption(0xFFF3E5F5), // Purple
                const SizedBox(width: 8),
                _colorOption(0xFFE8F5E9), // Green
                const SizedBox(width: 8),
                _colorOption(0xFFFFF3E0), // Orange
                const SizedBox(width: 8),
                _colorOption(0xFFE3F2FD), // Blue
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          
          // Fluttermoji Customizer
          Expanded(
            child: FluttermojiCustomizer(
              autosave: false,
              theme: FluttermojiThemeData(
                boxDecoration: const BoxDecoration(boxShadow: [BoxShadow()]), // minimal shadow
                primaryBgColor: isDark ? AppTheme.darkSurface : Colors.white,
                secondaryBgColor: isDark ? Colors.black12 : Colors.grey.shade100,
                labelTextStyle: theme.textTheme.bodySmall!,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorOption(int colorValue) {
    final isSelected = (_currentConfig['backgroundColor'] ?? 0xFFE0F7FA) == colorValue;
    return GestureDetector(
      onTap: () => _updateBgColor(colorValue),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Color(colorValue),
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: AppTheme.primaryColor, width: 2) : Border.all(color: Colors.black12),
        ),
      ),
    );
  }
}

