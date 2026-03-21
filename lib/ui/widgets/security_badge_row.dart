// lib/ui/widgets/security_badge_row.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants.dart';

/// Always-visible trust signal row: 🔒 E2EE | 📴 Offline | ✅ No Tracking
class SecurityBadgeRow extends StatelessWidget {
  final bool compact;
  const SecurityBadgeRow({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6, horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Badge(AppStrings.badge_e2ee, AppColors.primary),
            _Divider(),
            _Badge(AppStrings.badge_offline, AppColors.success),
            _Divider(),
            _Badge(AppStrings.badge_notrack, AppColors.secondary),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('·', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      );
}

/// Speed share viral card — "Shared 12 notes in 1.3s 👀"
class ViralSpeedCard extends StatelessWidget {
  final int noteCount;
  final Duration duration;
  final VoidCallback? onShare;

  const ViralSpeedCard({
    super.key,
    required this.noteCount,
    required this.duration,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final secs = (duration.inMilliseconds / 1000).toStringAsFixed(1);
    return GestureDetector(
      onTap: onShare,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.heroGradient),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const Text('⚡', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shared $noteCount notes in ${secs}s 👀',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const Text(
                    'Tap to share this moment',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.share_rounded, color: Colors.white70, size: 18),
          ],
        ),
      ),
    )
        .animate()
        .scale(begin: const Offset(0.9, 0.9), duration: 400.ms, curve: Curves.elasticOut)
        .fadeIn();
  }
}

/// NFC / Shake discovery overlay toast
class DiscoveredPeerToast extends StatelessWidget {
  final String peerName;
  final VoidCallback onConnect;
  final VoidCallback onDismiss;

  const DiscoveredPeerToast({
    super.key,
    required this.peerName,
    required this.onConnect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.person_add_outlined, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Found $peerName! ✨',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                const Text('Tap to connect & sync',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          TextButton(
            onPressed: onConnect,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.success.withOpacity(0.15),
              foregroundColor: AppColors.success,
              minimumSize: const Size(60, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sync', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, size: 16, color: Colors.white38),
          ),
        ],
      ),
    ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOut).fadeIn();
  }
}

/// Live cursor label shown in the editor above the text
class LiveCursorLabel extends StatelessWidget {
  final String name;
  final Color color;

  const LiveCursorLabel({super.key, required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}
