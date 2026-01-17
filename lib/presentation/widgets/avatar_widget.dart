import 'package:flutter/material.dart';
import '../../core/services/avatar_service.dart';

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
    // Extract colors
    final skinColor = Color(config['skinColor'] ?? 0xFFFFDFC4);
    final bgColor = Color(config['backgroundColor'] ?? 0xFFE0F7FA);
    final accessory = config['accessory'] ?? 'none';
    final shirt = config['shirt'] ?? 'tshirt_blue';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: size * 0.04), // Dynamic border width
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
        child: Stack(
          alignment: Alignment.center,
          children: [
             // 0. Base Body (Background)
             Positioned(
                 bottom: -size * 0.1,
                 child: Icon(Icons.person, size: size * 1.1, color: skinColor),
             ),
             
             // 1. Shirt (Simple overlay)
             if (shirt != 'none')
                 Positioned(
                     bottom: -size * 0.35,
                     child: Icon(Icons.shield, size: size * 1.0, color: _getShirtColor(shirt)), // Abstract shirt
                 ),

            // 2. Eyes/Face
            Positioned(
              top: size * 0.35,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEye(size),
                  SizedBox(width: size * 0.15),
                  _buildEye(size),
                ],
              ),
            ),
            
            // 3. Smile
             Positioned(
              top: size * 0.55,
              child: Container(
                width: size * 0.2,
                height: size * 0.08,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black87, width: size * 0.03)),
                  borderRadius: BorderRadius.circular(size),
                ),
              ),
             ),
             
             // 4. Accessories
             if (accessory == 'glasses')
                Positioned(
                  top: size * 0.35,
                  child: Icon(Icons.remove_red_eye_rounded, size: size * 0.45, color: Colors.indigo.withOpacity(0.8)),
                ),
             if (accessory == 'headphones')
                 Positioned(
                   top: size * 0.15,
                   child: Icon(Icons.headphones_rounded, size: size * 0.8, color: Colors.grey[800]),
                 ),
                 
             if (accessory == 'hat')
                  Positioned(
                    top: -size * 0.05,
                    child: Icon(Icons.school, size: size * 0.5, color: Colors.black87),
                  ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEye(double size) {
      return Container(
        width: size * 0.08, 
        height: size * 0.08, 
        decoration: BoxDecoration(
            color: Colors.black87, 
            shape: BoxShape.circle,
            boxShadow: [
                 BoxShadow(color: Colors.white, offset: Offset(-1, -1), blurRadius: 0, spreadRadius: size * 0.01) // Sparkle
            ]
        )
      );
  }
  
  Color _getShirtColor(String shirtId) {
      switch (shirtId) {
          case 'tshirt_red': return Colors.redAccent;
          case 'hoodie_grey': return Colors.grey;
          case 'suit': return Colors.blueGrey.shade900;
          default: return Colors.blueAccent;
      }
  }
}
