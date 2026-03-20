// lib/ui/screens/monetization/monetization_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../providers/purchase_provider.dart';
import '../../widgets/glass_card.dart';

class MonetizationScreen extends ConsumerStatefulWidget {
  const MonetizationScreen({super.key});

  @override
  ConsumerState<MonetizationScreen> createState() => _MonetizationScreenState();
}

class _MonetizationScreenState extends ConsumerState<MonetizationScreen> {
  bool _isLoading = false;
  String? _purchasingId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final purchase = ref.watch(purchaseProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Hero gradient background
          Container(
            height: 320,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.heroGradient,
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  // Back + title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Text(
                          'Upgrade',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Hero copy
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Text(
                          '🎉 Free Forever',
                          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No subscription. No monthly fees.\nPay once, own it forever.',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Trust badges
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _BadgeChip('🔒 E2EE'),
                            const SizedBox(width: 8),
                            _BadgeChip('📴 Offline'),
                            const SizedBox(width: 8),
                            _BadgeChip('✅ No Tracking'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Tier cards
                  ...[ 
                    _TierData(
                      emoji: '✅',
                      name: 'Free Forever',
                      price: 'Always Free',
                      productId: '',
                      color: AppColors.success,
                      features: ['Up to 5 peers', 'Unlimited notes', 'mDNS discovery', 'E2EE encryption', 'Markdown editor'],
                      isCurrent: !purchase.isProPeers,
                      isHighlighted: false,
                    ),
                    _TierData(
                      emoji: '🚀',
                      name: 'Pro',
                      price: '\$2',
                      subtitle: 'one-time',
                      productId: AppConstants.iapProPeers,
                      color: AppColors.primary,
                      features: ['Unlimited peers', 'Shake to discover', 'QR code connect', 'Priority sync', 'Everything in Free'],
                      isCurrent: purchase.isProPeers && !purchase.isVoice,
                      isHighlighted: false,
                    ),
                    _TierData(
                      emoji: '🎙️',
                      name: 'Voice',
                      price: '\$5',
                      subtitle: 'one-time',
                      productId: AppConstants.iapVoice,
                      color: AppColors.secondary,
                      features: ['Local voice-to-text', '95%+ accuracy', 'No internet needed', 'Everything in Pro'],
                      isCurrent: purchase.isVoice && !purchase.isAR,
                      isHighlighted: true,
                      highlightLabel: '⭐ Most Popular',
                    ),
                    _TierData(
                      emoji: '🔮',
                      name: 'AR',
                      price: '\$10',
                      subtitle: 'one-time',
                      productId: AppConstants.iapAR,
                      color: AppColors.tertiary,
                      features: ['AR whiteboard capture', 'Image-to-text AI', 'Camera quick-capture', 'Everything in Voice'],
                      isCurrent: purchase.isAR && !purchase.isEnterprise,
                      isHighlighted: false,
                    ),
                    _TierData(
                      emoji: '🏢',
                      name: 'Enterprise',
                      price: '\$20',
                      subtitle: 'one-time',
                      productId: AppConstants.iapEnterprise,
                      color: Color(0xFF8B5CF6),
                      features: ['500 peers per room', 'NFC tap-to-share', 'Room persistence', 'Priority support', 'Everything in AR'],
                      isCurrent: purchase.isEnterprise,
                      isHighlighted: false,
                    ),
                  ].asMap().entries.map((e) => _TierCard(
                    data: e.value,
                    isPurchasing: _purchasingId == e.value.productId,
                    onPurchase: e.value.productId.isEmpty ? null : () => _purchase(e.value.productId),
                  ).animate().fadeIn(delay: Duration(milliseconds: e.key * 80)).slideY(begin: 0.1)),

                  const SizedBox(height: 16),

                  // Restore purchases
                  TextButton(
                    onPressed: _restorePurchases,
                    child: const Text('Restore Purchases', style: TextStyle(color: Colors.grey)),
                  ),

                  const SizedBox(height: 8),

                  // Fine print
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'All purchases are lifetime one-time payments. '
                      'No subscription. No hidden fees. Works 100% offline forever.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(height: 1.5, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            const _LoadingOverlay(),
        ],
      ),
    );
  }

  Future<void> _purchase(String productId) async {
    setState(() { _isLoading = true; _purchasingId = productId; });
    final success = await ref.read(purchaseProvider.notifier).purchase(productId);
    setState(() { _isLoading = false; _purchasingId = null; });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(success ? Icons.check_circle : Icons.error_outline,
                color: success ? AppColors.success : AppColors.error, size: 16),
            const SizedBox(width: 8),
            Text(success ? '🎉 Unlocked! Enjoy your new features.' : 'Purchase failed. Please try again.'),
          ]),
          backgroundColor: success ? AppColors.success.withOpacity(0.9) : AppColors.error.withOpacity(0.9),
        ),
      );
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    final ok = await ref.read(purchaseProvider.notifier).restorePurchases();
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Purchases restored!' : 'Nothing to restore')),
      );
    }
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _TierData {
  final String emoji, name, price, productId;
  final String? subtitle, highlightLabel;
  final Color color;
  final List<String> features;
  final bool isCurrent, isHighlighted;

  const _TierData({
    required this.emoji, required this.name, required this.price,
    required this.productId, required this.color, required this.features,
    required this.isCurrent, required this.isHighlighted,
    this.subtitle, this.highlightLabel,
  });
}

// ─── Tier card ────────────────────────────────────────────────────────────────

class _TierCard extends StatelessWidget {
  final _TierData data;
  final bool isPurchasing;
  final VoidCallback? onPurchase;

  const _TierCard({required this.data, required this.isPurchasing, this.onPurchase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: data.isHighlighted ? data.color : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: data.isHighlighted ? 2 : 1,
          ),
          boxShadow: data.isHighlighted
              ? [BoxShadow(color: data.color.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(data.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(data.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          if (data.isHighlighted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: data.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(data.highlightLabel ?? '',
                                  style: TextStyle(fontSize: 9, color: data.color, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ]),
                        if (data.isCurrent)
                          Text('✓ Active', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(data.price,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800, color: data.color,
                          )),
                      if (data.subtitle != null)
                        Text(data.subtitle!, style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Features
              ...data.features.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Icon(Icons.check_circle, size: 14, color: data.color),
                  const SizedBox(width: 8),
                  Text(f, style: theme.textTheme.bodySmall),
                ]),
              )),

              if (onPurchase != null && !data.isCurrent) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isPurchasing ? null : onPurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: data.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isPurchasing
                        ? const SizedBox(height: 18, width: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Get ${data.name} — ${data.price}'),
                  ),
                ),
              ] else if (data.isCurrent) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: const Center(
                    child: Text('✓ Current Plan', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  const _BadgeChip(this.label);
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white30),
    ),
    child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
  );
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black38,
    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
  );
}
