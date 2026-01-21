import 'package:flutter/material.dart';
import 'package:fluttermoji/fluttermoji.dart';

class AvatarWidget extends StatelessWidget {
  final Map<String, dynamic> config;
  final double size;

  const AvatarWidget({
    super.key,
    required this.config,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    // Note: 'config' is now largely unused for the internal look of the avatar
    // because FlutterMoji maintains its own state in local storage.
    // However, we still use the container decoration for the background context.
    
    final bgColor = Color(config['backgroundColor'] ?? 0xFFE0F7FA);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: size * 0.04),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: size * 0.1,
            offset: Offset(0, size * 0.04),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgColor,
            Color.alphaBlend(Colors.black.withOpacity(0.05), bgColor),
          ],
        ),
      ),
      child: ClipOval(
        child: FluttermojiCircleAvatar(
          backgroundColor: Colors.transparent,
          radius: size / 2,
        ),
      ),
    );
  }
}

