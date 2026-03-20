// lib/ui/widgets/sync_status_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants.dart';
import '../../providers/peers_provider.dart';

class SyncStatusBar extends StatelessWidget {
  final SyncState syncState;
  const SyncStatusBar({super.key, required this.syncState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (bg, fg, icon) = switch (syncState.status) {
      SyncStatus.syncing  => (AppColors.primary.withOpacity(0.08), AppColors.primary,    Icons.sync_rounded),
      SyncStatus.success  => (AppColors.success.withOpacity(0.08), AppColors.success,    Icons.check_circle_outline_rounded),
      SyncStatus.conflict => (AppColors.warning.withOpacity(0.08), AppColors.warning,    Icons.warning_amber_rounded),
      SyncStatus.error    => (AppColors.error.withOpacity(0.08),   AppColors.error,      Icons.error_outline_rounded),
      _                   => (Colors.transparent,                   Colors.transparent,  Icons.info_outline),
    };

    return AnimatedContainer(
      duration: AppConstants.animationFast,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: fg.withOpacity(0.18))),
      ),
      child: Row(
        children: [
          if (syncState.status == SyncStatus.syncing)
            SizedBox(
              width: 15, height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          else
            Icon(icon, size: 15, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              syncState.message ?? '',
              style: theme.textTheme.labelMedium?.copyWith(
                color: fg, fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (syncState.total > 0 && syncState.status == SyncStatus.syncing) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: fg.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${syncState.progress}/${syncState.total}',
                style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    ).animate().slideY(begin: -1, duration: AppConstants.animationFast, curve: Curves.easeOut);
  }
}

// ─── Network mode badge ───────────────────────────────────────────────────────

class NetworkModeBadge extends StatelessWidget {
  final String mode;
  final String tier;
  final bool isOnline;
  const NetworkModeBadge({super.key, required this.mode, required this.tier, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.success : Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ).animate(onPlay: isOnline ? (c) => c.repeat(reverse: true) : null)
            .scaleXY(begin: 1, end: 1.4, duration: 1000.ms)
            .then().scaleXY(begin: 1.4, end: 1, duration: 1000.ms),
        const SizedBox(width: 5),
        Text(
          isOnline ? '$mode · $tier' : 'Offline',
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
