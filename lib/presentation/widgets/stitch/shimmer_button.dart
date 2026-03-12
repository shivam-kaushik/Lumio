import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// A button with animated shimmer effect
/// Based on Stitch AI welcome screen "Get Started" button
class ShimmerButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? trailingIcon;
  final bool isLoading;

  const ShimmerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon,
    this.isLoading = false,
  });

  @override
  State<ShimmerButton> createState() => _ShimmerButtonState();
}

class _ShimmerButtonState extends State<ShimmerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.isLoading ? null : widget.onPressed,
        borderRadius: LumioRadius.radiusFull,
        child: Container(
          width: double.infinity,
          height: LumioSpacing.buttonHeightLarge,
          decoration: BoxDecoration(
            color: LumioColors.primary,
            borderRadius: LumioRadius.radiusFull,
            boxShadow: [
              BoxShadow(
                color: LumioColors.primary.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: LumioRadius.radiusFull,
            child: Stack(
              children: [
                // Shimmer effect
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return Positioned(
                      left: _shimmerAnimation.value *
                          MediaQuery.of(context).size.width,
                      top: 0,
                      bottom: 0,
                      width: 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Button content
                Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.label,
                              style: LumioTypography.ctaButton.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            if (widget.trailingIcon != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                widget.trailingIcon,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
