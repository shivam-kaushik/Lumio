import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme.dart';
import '../navigation/main_navigator.dart';
import '../../core/services/permission_service.dart';
import 'login_screen.dart';

/// Persona types for onboarding
enum PersonaType {
  founder,
  freelancer,
  creator,
}

/// Welcome/Onboarding screen based on Stitch AI mockup
/// Features persona selection with "Turn Ambition Into Action" branding
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  PersonaType? _selectedPersona;
  bool _isLoading = false;

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _onGetStarted() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Save selected persona
      if (_selectedPersona != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_persona', _selectedPersona!.name);
      }

      // Request permissions
      if (mounted) {
        final permissionService = context.read<PermissionService>();
        await permissionService.requestAllPermissions();
      }

      // Mark onboarding as complete
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);

      if (!mounted) return;

      // Navigate to main app
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainNavigator()),
      );
    } catch (e) {
      debugPrint('Error in onboarding: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LumioColors.warmGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: LumioSpacing.screenHorizontalPadding,
            child: Column(
              children: [
                LumioSpacing.verticalGap16,

                // Pagination indicators
                _buildPaginationDots(),

                LumioSpacing.verticalGap24,

                // Hero section with lightbulb
                Expanded(
                  flex: 3,
                  child: _buildHeroSection(),
                ),

                LumioSpacing.verticalGap32,

                // Header text
                _buildHeaderText(),

                LumioSpacing.verticalGap32,

                // Persona selection
                _buildPersonaSelection(),

                LumioSpacing.verticalGap32,

                // CTA button
                _buildCtaButton(),

                LumioSpacing.verticalGap16,

                // Login link
                _buildLoginLink(),

                LumioSpacing.verticalGap24,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 32 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? LumioColors.primary
                : LumioColors.primary.withOpacity(0.2),
            borderRadius: LumioRadius.radiusFull,
          ),
        );
      }),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: LumioSpacing.paddingLG,
      decoration: BoxDecoration(
        color: LumioColors.surface(context).withOpacity(0.4),
        borderRadius: LumioRadius.radiusLG,
        border: Border.all(
          color: LumioColors.surface(context).withOpacity(0.5),
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer decorative ring
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: LumioColors.primary.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),

            // Middle decorative ring
            Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: LumioColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),

            // Glow effect
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    LumioColors.primary.withOpacity(0.15),
                    LumioColors.primary.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // Inner gradient circle with icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    LumioColors.primary.withOpacity(0.15),
                    LumioColors.primary.withOpacity(0.05),
                  ],
                ),
              ),
              child: Icon(
                Icons.lightbulb_outline_rounded,
                size: 64,
                color: LumioColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderText() {
    return Column(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Turn Ambition\n',
                style: LumioTypography.displaySmall.copyWith(
                  color: LumioColors.textPrimary(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: 'Into Action',
                style: LumioTypography.displaySmall.copyWith(
                  color: LumioColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        LumioSpacing.verticalGap16,
        Padding(
          padding: LumioSpacing.horizontalMD,
          child: Text(
            'Lumio is your AI-powered goal engine, designed to help solopreneurs focus, plan, and achieve more.',
            style: LumioTypography.bodyLarge.copyWith(
              color: LumioColors.textSecondary(context),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonaSelection() {
    return Column(
      children: [
        Text(
          'I IDENTIFY AS A',
          style: LumioTypography.labelSmall.copyWith(
            color: LumioColors.textTertiary(context),
            letterSpacing: 2,
          ),
        ),
        LumioSpacing.verticalGap16,
        Row(
          children: [
            Expanded(
              child: _buildPersonaCard(
                icon: Icons.business_center_outlined,
                label: 'Founder',
                persona: PersonaType.founder,
              ),
            ),
            LumioSpacing.horizontalGap12,
            Expanded(
              child: _buildPersonaCard(
                icon: Icons.edit_note_rounded,
                label: 'Freelancer',
                persona: PersonaType.freelancer,
              ),
            ),
            LumioSpacing.horizontalGap12,
            Expanded(
              child: _buildPersonaCard(
                icon: Icons.videocam_outlined,
                label: 'Creator',
                persona: PersonaType.creator,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPersonaCard({
    required IconData icon,
    required String label,
    required PersonaType persona,
  }) {
    final isSelected = _selectedPersona == persona;

    return GestureDetector(
      onTap: () => setState(() => _selectedPersona = persona),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: LumioSpacing.paddingMD,
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: LumioRadius.radiusLG,
          border: Border.all(
            color: isSelected ? LumioColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: LumioColors.primary.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : LumioShadows.extraSoft,
        ),
        child: Column(
          children: [
            // Selection indicator
            if (isSelected)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: LumioColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            else
              const SizedBox(height: 8),

            // Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? LumioColors.primary : LumioColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? Colors.white : LumioColors.primary,
              ),
            ),

            LumioSpacing.verticalGap12,

            Text(
              label,
              style: LumioTypography.labelMedium.copyWith(
                color: LumioColors.textPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCtaButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _onGetStarted,
      child: AnimatedBuilder(
        animation: _shimmerAnimation,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: LumioSpacing.buttonHeightLarge,
            decoration: BoxDecoration(
              color: LumioColors.primary,
              borderRadius: LumioRadius.radiusFull,
              boxShadow: LumioShadows.fab,
            ),
            child: ClipRRect(
              borderRadius: LumioRadius.radiusFull,
              child: Stack(
                children: [
                  // Shimmer effect
                  Positioned(
                    left: _shimmerAnimation.value * MediaQuery.of(context).size.width,
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
                  ),

                  // Button content
                  Center(
                    child: _isLoading
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
                            children: [
                              Text(
                                'Get Started',
                                style: LumioTypography.ctaButton.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: LumioTypography.bodyMedium.copyWith(
            color: LumioColors.textSecondary(context),
          ),
        ),
        GestureDetector(
          onTap: _goToLogin,
          child: Text(
            'Log in',
            style: LumioTypography.bodyMedium.copyWith(
              color: LumioColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
