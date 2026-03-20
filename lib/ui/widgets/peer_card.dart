// lib/ui/widgets/peer_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants.dart';
import '../../models/peer.dart';
import 'peer_avatar.dart';

class PeerCard extends StatelessWidget {
  final DiscoveredPeer peer;
  final bool isSyncing;
  final VoidCallback onConnect;
  final VoidCallback onSync;
  final VoidCallback onShare;
  final VoidCallback onViewNotes;
  final String? networkTier; // e.g. "Direct P2P", "STUN", "TURN relay"

  const PeerCard({
    super.key,
    required this.peer,
    required this.isSyncing,
    required this.onConnect,
    required this.onSync,
    required this.onShare,
    required this.onViewNotes,
    this.networkTier,
  });

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: isDark ? const Color(0xFF1A2235) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onViewNotes,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: peer.status == PeerStatus.connected
                    ? peer.statusColor.withOpacity(0.4)
                    : isDark ? const Color(0xFF263048) : const Color(0xFFE8ECF4),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Top row ────────────────────────────────────────────────
                Row(
                  children: [
                    // Avatar with animated status ring
                    _AnimatedAvatar(peer: peer, isSyncing: isSyncing, isDark: isDark),
                    const SizedBox(width: 14),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            peer.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700, letterSpacing: -0.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          _MetaRow(peer: peer, networkTier: networkTier),
                          const SizedBox(height: 3),
                          _StatusRow(peer: peer, isSyncing: isSyncing),
                        ],
                      ),
                    ),

                    // Note count badge
                    _NoteCountBadge(count: peer.noteCount),
                  ],
                ),

                // ── Actions / progress ────────────────────────────────────
                const SizedBox(height: 12),
                isSyncing
                    ? _SyncProgress()
                    : _ActionRow(
                        peer: peer,
                        onConnect: onConnect,
                        onSync: onSync,
                        onShare: onShare,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Animated avatar ──────────────────────────────────────────────────────────

class _AnimatedAvatar extends StatelessWidget {
  final DiscoveredPeer peer;
  final bool isSyncing, isDark;
  const _AnimatedAvatar({required this.peer, required this.isSyncing, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        children: [
          PeerAvatar(peer: peer, size: 52),
          if (isSyncing)
            Positioned.fill(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(AppColors.warning),
              ).animate(onPlay: (c) => c.repeat()).rotate(duration: 900.ms),
            )
          else
            Positioned(
              right: 1, bottom: 1,
              child: Container(
                width: 13, height: 13,
                decoration: BoxDecoration(
                  color: peer.statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF1A2235) : Colors.white,
                    width: 2.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Meta row ────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final DiscoveredPeer peer;
  final String? networkTier;
  const _MetaRow({required this.peer, this.networkTier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          peer.isWebPeer ? Icons.language_rounded : Icons.wifi_rounded,
          size: 11,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            networkTier ?? (peer.isWebPeer ? 'WebRTC' : peer.host),
            style: theme.textTheme.labelSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Status row ───────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final DiscoveredPeer peer;
  final bool isSyncing;
  const _StatusRow({required this.peer, required this.isSyncing});

  @override
  Widget build(BuildContext context) {
    final color = peer.statusColor;
    final label = isSyncing ? 'Syncing…' : peer.statusText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSyncing)
          SizedBox(
            width: 8, height: 8,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
          )
        else
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Note count badge ─────────────────────────────────────────────────────────

class _NoteCountBadge extends StatelessWidget {
  final int count;
  const _NoteCountBadge({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary,
              ),
            ),
            const Text(
              'notes',
              style: TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
}

// ─── Sync progress ────────────────────────────────────────────────────────────

class _SyncProgress extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              color: AppColors.warning,
              backgroundColor: AppColors.warning.withOpacity(0.15),
              minHeight: 4,
            ).animate(onPlay: (c) => c.repeat()).shimmer(
              duration: 1200.ms, color: Colors.white24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Syncing notes…',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.warning, fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

// ─── Action row ───────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final DiscoveredPeer peer;
  final VoidCallback onConnect, onSync, onShare;

  const _ActionRow({
    required this.peer,
    required this.onConnect,
    required this.onSync,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = peer.status == PeerStatus.connected;
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            label: isConnected ? 'Sync' : 'Connect',
            icon: isConnected ? Icons.sync_rounded : Icons.link_rounded,
            color: AppColors.primary,
            onTap: isConnected ? onSync : onConnect,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionBtn(
            label: 'Share',
            icon: Icons.share_outlined,
            color: AppColors.secondary,
            onTap: onShare,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionBtn(
            label: 'Browse',
            icon: Icons.list_alt_rounded,
            color: AppColors.tertiary,
            onTap: null, // handled by card tap
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
