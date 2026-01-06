import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/services/premium_service.dart';
import '../../core/services/iap_service.dart';
import '../theme/app_theme.dart';

/// Screen to display premium features and handle subscription
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
    if (mounted) {
      setState(() {}); // Rebuild to show products/loading
      if (_iapService.purchaseError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_iapService.purchaseError!)),
        );
      }
    }
  }

  Future<void> _handlePurchase(ProductDetails? product) async {
    if (product == null) return;
    
    setState(() => _isLoading = true);
    await _iapService.buyProduct(product);
    // Loading state is managed by IAP stream updates mostly, but we can reset here
    setState(() => _isLoading = false);
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    await _iapService.restorePurchases();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Find monthly product
    final monthlyProduct = _iapService.products.cast<ProductDetails>().firstWhere(
      (p) => p.id == IAPService.kMonthlySubscriptionId,
      orElse: () => ProductDetails(
        id: 'premium_monthly',
        title: 'Premium Monthly',
        description: '',
        price: '\$4.99',
        rawPrice: 4.99,
        currencyCode: 'USD',
      ), // Dummy fallback for UI testing if store not connected
    );

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          // Background Gradient decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.purple.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
           Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blue.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _isLoading ? null : _handleRestore,
                        child: Text(
                          'Restore Purchases',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Crown Icon
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star_rounded, size: 60, color: Colors.amber)
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2.seconds),
                        ),
                        const SizedBox(height: 24),
                        
                        Text(
                          'Unlock Lumio Premium',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Supercharge your productivity with\nAI-powered tools and insights.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 48),

                        // Features List
                        ..._features.map((feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (feature['color'] as Color).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  feature['icon'] as IconData,
                                  color: feature['color'] as Color,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      feature['title'],
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      feature['description'],
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: isDark ? Colors.white60 : Colors.black54,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ).animate().fadeIn().slideX(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOut),
                        )),
                        
                        const SizedBox(height: 100), // Bottom padding
                      ],
                    ),
                  ),
                ),

                // Bottom CTA
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isLoading || _iapService.isLoading) ? null : () => _handlePurchase(monthlyProduct),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                          ),
                          child: (_isLoading || _iapService.isLoading)
                            ? const SizedBox(
                                height: 24, 
                                width: 24, 
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              )
                            : Text(
                                'Upgrade for ${monthlyProduct.price}/mo',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Recurring billing. Cancel anytime.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      if (!_iapService.isAvailable)
                         Padding(
                           padding: const EdgeInsets.only(top: 8),
                           child: Text(
                            'Store unavailable or not connected',
                            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.errorColor),
                                                   ),
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
