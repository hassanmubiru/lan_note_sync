// lib/ui/widgets/empty_state.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? custom;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.custom,
  });

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container with gradient glow
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.primary.withOpacity(isDark ? 0.25 : 0.12),
                  AppColors.primary.withOpacity(0),
                ]),
              ),
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.08),
                  ),
                  child: Icon(icon, size: 30, color: AppColors.primary.withOpacity(0.7)),
                ),
              ),
            )
                .animate()
                .scaleXY(begin: 0.7, duration: 500.ms, curve: Curves.elasticOut)
                .fadeIn(duration: 300.ms),

            const SizedBox(height: 22),

            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700, letterSpacing: -0.1,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.15, curve: Curves.easeOut),

            const SizedBox(height: 8),

            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurface.withOpacity(0.45),
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 150.ms),

            if (custom != null) ...[
              const SizedBox(height: 20),
              custom!.animate().fadeIn(delay: 200.ms),
            ],

            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
            ],
          ],
        ),
      ),
    );
  }
}
