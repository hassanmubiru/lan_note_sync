// lib/ui/widgets/glass_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.blurSigma = 12,
    this.opacity = 0.12,
    this.borderRadius,
    this.padding,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final br = borderRadius ?? BorderRadius.circular(16);

    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(opacity),
            borderRadius: br,
            border: Border.all(
              color: borderColor ?? (isDark ? Colors.white12 : Colors.white60),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Prominent glass banner (e.g. "Shake to discover")
class ShakeBanner extends StatefulWidget {
  final VoidCallback onShake;
  final int peerCount;

  const ShakeBanner({super.key, required this.onShake, required this.peerCount});

  @override
  State<ShakeBanner> createState() => _ShakeBannerState();
}

class _ShakeBannerState extends State<ShakeBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: widget.onShake,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withOpacity(0.15), AppColors.secondary.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Transform.rotate(
                angle: (_ctrl.value - 0.5) * 0.3,
                child: const Text('👋', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Shake to find teammates',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  if (widget.peerCount > 0)
                    Text(
                      '${widget.peerCount} peer${widget.peerCount != 1 ? 's' : ''} nearby',
                      style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500),
                    )
                  else
                    Text('Shake or tap to scan', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.primary.withOpacity(0.7), size: 18),
          ],
        ),
      ),
    );
  }
}
