import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/services/premium_service.dart';
import '../../core/services/iap_service.dart';
import '../theme/theme.dart';

class PremiumSubscriptionScreen extends StatefulWidget {
  const PremiumSubscriptionScreen({super.key});

  @override
  State<PremiumSubscriptionScreen> createState() => _PremiumSubscriptionScreenState();
}

class _PremiumSubscriptionScreenState extends State<PremiumSubscriptionScreen> {
  final IAPService _iapService = IAPService();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.psychology_rounded,
      'title': 'AI Personal Assistant',
      'description': 'Chat with Lumio for personalized coaching and productivity advice.',
      'color': Colors.purple,
    },
    {
      'icon': Icons.account_tree_rounded,
      'title': 'Smart Roadmap Generation',
      'description': 'Turn vague goals into detailed, actionable execution plans instantly.',
      'color': Colors.blue,
    },
    {
      'icon': Icons.checklist_rounded,
      'title': 'Intelligent Breakdown',
      'description': 'Let AI break down complex tasks into manageable subtasks for you.',
      'color': Colors.orange,
    },
    {
      'icon': Icons.security_rounded,
      'title': 'Privacy-First AI',
      'description': 'Your data is anonymized before processing. Secure and private.',
      'color': Colors.green,
    },
  ];

  @override
  void initState() {
    super.initState();
    _iapService.addListener(_onIapUpdate);
    _iapService.initialize();
  }

  @override
  void dispose() {
    _iapService.removeListener(_onIapUpdate);
    super.dispose();
  }

  void _onIapUpdate() {
    if (!mounted) return;
    setState(() {});
    if (_iapService.purchaseError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_iapService.purchaseError!), backgroundColor: LumioColors.error));
    }
  }

  Future<void> _handlePurchase(ProductDetails? product) async {
    if (product == null) return;
    setState(() => _isLoading = true);
    await _iapService.buyProduct(product);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    await _iapService.restorePurchases();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;

    final monthlyProduct = _iapService.products.cast<ProductDetails?>().firstWhere(
      (p) => p?.id == IAPService.kMonthlySubscriptionId,
      orElse: () => ProductDetails(
        id: 'premium_monthly',
        title: 'Premium Monthly',
        description: '',
        price: '\$4.99',
        rawPrice: 4.99,
        currencyCode: 'USD',
      ),
    );

    return Scaffold(
      backgroundColor: LumioColors.background(context),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [LumioColors.primary.withValues(alpha: 0.15), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Colors.blue.withValues(alpha: 0.1), Colors.transparent]),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(LumioSpacing.md),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        color: LumioColors.textPrimary(context),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _isLoading ? null : _handleRestore,
                        child: Text('Restore Purchases', style: TextStyle(color: LumioColors.textSecondary(context), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: LumioSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: LumioSpacing.lg),
                        Container(
                          padding: const EdgeInsets.all(LumioSpacing.lg),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star_rounded, size: 56, color: Colors.amber)
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2.seconds),
                        ),
                        const SizedBox(height: LumioSpacing.lg),
                        Text('Unlock Lumio Premium', style: LumioTypography.headlineLarge.copyWith(color: LumioColors.textPrimary(context)), textAlign: TextAlign.center),
                        const SizedBox(height: LumioSpacing.sm),
                        Text(
                          'Supercharge your productivity with\nAI-powered tools and insights.',
                          style: LumioTypography.bodyLarge.copyWith(color: LumioColors.textSecondary(context), height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: LumioSpacing.xl),
                        ..._features.map((feature) => Padding(
                          padding: const EdgeInsets.only(bottom: LumioSpacing.lg),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(LumioSpacing.sm + 4),
                                decoration: BoxDecoration(
                                  color: (feature['color'] as Color).withValues(alpha: 0.1),
                                  borderRadius: LumioRadius.radiusMD,
                                ),
                                child: Icon(feature['icon'] as IconData, color: feature['color'] as Color, size: 26),
                              ),
                              const SizedBox(width: LumioSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(feature['title'] as String, style: LumioTypography.titleSmall.copyWith(color: LumioColors.textPrimary(context))),
                                    const SizedBox(height: LumioSpacing.xs),
                                    Text(feature['description'] as String, style: LumioTypography.bodySmall.copyWith(color: LumioColors.textSecondary(context), height: 1.4)),
                                  ],
                                ),
                              ),
                            ],
                          ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.15, end: 0, duration: 400.ms, curve: Curves.easeOut),
                        )),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),

                // Bottom CTA
                Container(
                  padding: const EdgeInsets.all(LumioSpacing.lg),
                  decoration: BoxDecoration(
                    color: LumioColors.surface(context),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -5))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_isLoading || _iapService.isLoading) ? null : () => _handlePurchase(monthlyProduct),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isIOS ? Colors.black : LumioColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: LumioRadius.button),
                            elevation: 0,
                          ),
                          child: (_isLoading || _iapService.isLoading)
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isIOS) ...[
                                      const Icon(Icons.apple, size: 20),
                                      const SizedBox(width: LumioSpacing.xs),
                                      Text('Subscribe with Apple — ${monthlyProduct?.price ?? '\$4.99'}/mo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                    ] else ...[
                                      Image.asset('assets/google_play_icon.png', width: 20, height: 20, errorBuilder: (_, __, ___) => const Icon(Icons.play_arrow_rounded, size: 20)),
                                      const SizedBox(width: LumioSpacing.xs),
                                      Text('Subscribe — ${monthlyProduct?.price ?? '\$4.99'}/mo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: LumioSpacing.sm),
                      Text(
                        isIOS
                            ? 'Payment charged to your Apple ID. Cancel anytime.'
                            : 'Payment processed by Google Play. Cancel anytime.',
                        style: LumioTypography.bodySmall.copyWith(color: LumioColors.textSecondary(context)),
                        textAlign: TextAlign.center,
                      ),
                      if (!_iapService.isAvailable)
                        Padding(
                          padding: const EdgeInsets.only(top: LumioSpacing.xs),
                          child: Text('Store unavailable — check your connection', style: LumioTypography.bodySmall.copyWith(color: LumioColors.error)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the subscription / plan purchase screen (used from premium-gated dialogs).
Future<void> openPremiumPaywall(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => const PremiumSubscriptionScreen(),
    ),
  );
}

