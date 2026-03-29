import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/permission_service.dart';
import '../theme/theme.dart';
import 'login_screen.dart';

/// Stitch-style onboarding screen with persona selection
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _selectedPersona;

  final List<Map<String, dynamic>> _personas = [
    {
      'id': 'founder',
      'title': 'Founder',
      'icon': Icons.business_center_outlined,
    },
    {
      'id': 'freelancer',
      'title': 'Freelancer',
      'icon': Icons.edit_note_outlined,
    },
    {
      'id': 'creator',
      'title': 'Creator',
      'icon': Icons.videocam_outlined,
    },
  ];

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Turn Ambition',
      titleHighlight: 'Into Action',
      description:
          'Lumio is your AI-powered goal engine, designed to help solopreneurs focus, plan, and achieve more.',
      icon: Icons.lightbulb_outline_rounded,
      showPersonaSelection: true,
    ),
    OnboardingPage(
      title: 'Smart',
      titleHighlight: 'Planning',
      description:
          'Uses AI to break down your goals into actionable steps and schedules them intelligently.',
      icon: Icons.auto_awesome_outlined,
      showPersonaSelection: false,
    ),
    OnboardingPage(
      title: 'Context-Aware',
      titleHighlight: 'Reminders',
      description:
          'Get reminded at the right place and time based on your context, not just when the clock says so.',
      icon: Icons.notifications_active_outlined,
      showPersonaSelection: false,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final permissionService = context.read<PermissionService>();
    await permissionService.requestAllPermissions();

    if (!mounted) return;

    // Mark onboarding as seen so returning users go straight to login
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    if (!mounted) return;

    // Always require sign-in — never jump directly into the app
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF221A10) : const Color(0xFFF8F7F6);
    final textColor = isDark ? Colors.white : const Color(0xFF1B150D);
    final mutedColor = isDark ? Colors.grey[400]! : const Color(0xFF6B5E4F);
    final surfaceColor = isDark ? const Color(0xFF2D2418) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF221A10), const Color(0xFF1A1408)]
                : [const Color(0xFFFCFAF8), const Color(0xFFF4EFE9)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Pagination dots
              _buildPaginationDots(),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(
                      _pages[index],
                      isDark,
                      textColor,
                      mutedColor,
                      surfaceColor,
                    );
                  },
                ),
              ),

              // CTA Section
              _buildCTASection(isDark, textColor, mutedColor),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pages.length, (index) {
          final isActive = index == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 32 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? LumioColors.primary
                  : LumioColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPage(
    OnboardingPage page,
    bool isDark,
    Color textColor,
    Color mutedColor,
    Color surfaceColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Hero illustration
          _buildHeroIllustration(page, isDark, surfaceColor),

          const SizedBox(height: 32),

          // Header
          _buildHeader(page, textColor, mutedColor),

          const SizedBox(height: 32),

          // Persona selection (only on first page)
          if (page.showPersonaSelection)
            _buildPersonaSelection(isDark, textColor, surfaceColor),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeroIllustration(
    OnboardingPage page,
    bool isDark,
    Color surfaceColor,
  ) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: surfaceColor.withOpacity(0.5),
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer decorative ring
            Container(
              width: 180,
              height: 180,
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
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: LumioColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),

            // Main circle with gradient
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    LumioColors.primary.withOpacity(0.1),
                    LumioColors.primary.withOpacity(0.05),
                  ],
                ),
              ),
              child: Icon(
                page.icon,
                size: 56,
                color: LumioColors.primary,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 2000.ms,
                  curve: Curves.easeInOut,
                ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 500.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildHeader(OnboardingPage page, Color textColor, Color mutedColor) {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: textColor,
              height: 1.1,
              letterSpacing: -0.5,
            ),
            children: [
              TextSpan(text: '${page.title}\n'),
              TextSpan(
                text: page.titleHighlight,
                style: const TextStyle(color: LumioColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          page.description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: mutedColor,
            height: 1.5,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(
          begin: 0.1,
          end: 0,
          duration: 400.ms,
          delay: 200.ms,
        );
  }

  Widget _buildPersonaSelection(bool isDark, Color textColor, Color surfaceColor) {
    return Column(
      children: [
        Text(
          'I IDENTIFY AS A',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor.withOpacity(0.5),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: _personas.map((persona) {
            final isSelected = _selectedPersona == persona['id'];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: persona == _personas.first ? 0 : 6,
                  right: persona == _personas.last ? 0 : 6,
                ),
                child: _buildPersonaCard(
                  persona,
                  isSelected,
                  isDark,
                  textColor,
                  surfaceColor,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(
          begin: 0.1,
          end: 0,
          duration: 400.ms,
          delay: 400.ms,
        );
  }

  Widget _buildPersonaCard(
    Map<String, dynamic> persona,
    bool isSelected,
    bool isDark,
    Color textColor,
    Color surfaceColor,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPersona = persona['id'];
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? LumioColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? LumioColors.primary.withOpacity(0.15)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Selected indicator
            if (isSelected)
              Positioned(
                top: 0,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: LumioColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

            // Content
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? LumioColors.primary
                        : LumioColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    persona['icon'],
                    size: 24,
                    color: isSelected ? Colors.white : LumioColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  persona['title'],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCTASection(bool isDark, Color textColor, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Get Started Button
          GestureDetector(
            onTap: () {
              if (_currentPage == _pages.length - 1) {
                _requestPermissions();
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: LumioColors.primary,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: LumioColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.black : const Color(0xFF1B150D),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: isDark ? Colors.black : const Color(0xFF1B150D),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Login link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: mutedColor,
                ),
              ),
              GestureDetector(
                onTap: _navigateToLogin,
                child: const Text(
                  'Log in',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: LumioColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String titleHighlight;
  final String description;
  final IconData icon;
  final bool showPersonaSelection;

  OnboardingPage({
    required this.title,
    required this.titleHighlight,
    required this.description,
    required this.icon,
    this.showPersonaSelection = false,
  });
}
