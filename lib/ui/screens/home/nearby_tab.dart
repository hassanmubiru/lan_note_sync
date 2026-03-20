// lib/ui/screens/home/nearby_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../models/peer.dart';
import '../../../providers/peers_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/notes_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/peer_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/sync_status_bar.dart';

class NearbyTab extends ConsumerStatefulWidget {
  const NearbyTab({super.key});

  @override
  ConsumerState<NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends ConsumerState<NearbyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final peersAsync = ref.watch(peersProvider);
    final syncState  = ref.watch(syncStateProvider);
    final netStatus  = ref.watch(connectivityProvider).maybeWhen(
      data: (s) => s, orElse: () => null,
    );

    return RefreshIndicator(
      onRefresh: () => ref.read(peersProvider.notifier).refresh(),
      color: AppColors.secondary,
      child: peersAsync.when(
        loading: () => const _SkeletonList(),
        error:   (e, _) => _ErrorView(error: e.toString()),
        data: (peers) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Network status header
              SliverToBoxAdapter(
                child: _NetworkHeader(
                  peerCount: peers.length,
                  netStatus: netStatus,
                ),
              ),

              // Peer list
              if (peers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.wifi_tethering_rounded,
                    title: 'No devices nearby',
                    subtitle: 'Devices on your network running LanNote Sync\nwill appear here automatically.',
                    actionLabel: 'Refresh',
                    onAction: () => ref.read(peersProvider.notifier).refresh(),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final peer      = peers[index];
                      final isSyncing = syncState.activePeerId == peer.id &&
                          syncState.status == SyncStatus.syncing;
                      return PeerCard(
                        peer: peer,
                        isSyncing: isSyncing,
                        networkTier: netStatus?.tierLabel,
                        onConnect:   () => ref.read(syncStateProvider.notifier).syncWithPeer(peer),
                        onSync:      () => ref.read(syncStateProvider.notifier).syncWithPeer(peer),
                        onShare:     () => _showShareSheet(context, peer),
                        onViewNotes: () => context.push('/peer/${peer.id}', extra: peer),
                      ).animate().fadeIn(
                        delay: Duration(milliseconds: index * 60),
                        duration: AppConstants.animationFast,
                      ).slideX(begin: 0.04, end: 0);
                    },
                    childCount: peers.length,
                  ),
                ),

              // Manual connect card
              SliverToBoxAdapter(child: _ManualConnectCard()),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  void _showShareSheet(BuildContext context, DiscoveredPeer peer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ShareOptionsSheet(peer: peer),
    );
  }
}

// ─── Network header ───────────────────────────────────────────────────────────

class _NetworkHeader extends StatelessWidget {
  final int peerCount;
  final dynamic netStatus;
  const _NetworkHeader({required this.peerCount, this.netStatus});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          // Live discovery pulse
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(
              color: AppColors.success, shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scaleXY(begin: 1, end: 1.5, duration: 900.ms)
              .then().scaleXY(begin: 1.5, end: 1, duration: 900.ms),
          const SizedBox(width: 8),
          Text(
            'Scanning network…',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.success, fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (netStatus != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                netStatus.displayMode,
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Manual connect card ──────────────────────────────────────────────────────

class _ManualConnectCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ManualConnectCard> createState() => _ManualConnectCardState();
}

class _ManualConnectCardState extends ConsumerState<_ManualConnectCard> {
  bool _expanded = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: isDark ? const Color(0xFF1A2235) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0xFF263048) : const Color(0xFFE8ECF4),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_link_rounded, color: AppColors.primary, size: 18),
                  ),
                  title: const Text('Connect manually', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    'IP address, hostname, or LanNote QR URL',
                    style: theme.textTheme.labelSmall,
                  ),
                  trailing: Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 20,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
                if (_expanded) ...[
                  Divider(height: 1, color: isDark ? const Color(0xFF263048) : const Color(0xFFE8ECF4)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _ctrl,
                          decoration: const InputDecoration(
                            hintText: '192.168.1.x  ·  hostname:3030  ·  lannote://...',
                            prefixIcon: Icon(Icons.wifi_rounded, size: 18),
                            labelText: 'Peer address',
                          ),
                          keyboardType: TextInputType.url,
                          autofocus: true,
                          onSubmitted: (_) => _connect(),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Works on any network — local or internet',
                          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _connect,
                            icon: const Icon(Icons.connect_without_contact_rounded, size: 16),
                            label: const Text('Connect'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _connect() {
    final input = _ctrl.text.trim();
    if (input.isEmpty) return;

    String host;
    int port = AppConstants.servicePort;

    if (input.startsWith('lannote://')) {
      try {
        final uri = Uri.parse(input);
        host = uri.queryParameters['h'] ?? '';
        port = int.tryParse(uri.queryParameters['p'] ?? '') ?? AppConstants.servicePort;
      } catch (_) { return; }
    } else if (input.contains(':')) {
      final parts = input.split(':');
      host = parts[0].trim();
      port = int.tryParse(parts[1].trim()) ?? AppConstants.servicePort;
    } else {
      host = input;
    }

    if (host.isEmpty) return;

    final peer = DiscoveredPeer(
      id: 'manual-$host',
      name: host,
      host: host,
      port: port,
      lastSeen: DateTime.now(),
    );

    ref.read(syncStateProvider.notifier).syncWithPeer(peer);
    setState(() { _expanded = false; });
    _ctrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to $host…')),
    );
  }
}

// ─── Share options ────────────────────────────────────────────────────────────

class _ShareOptionsSheet extends ConsumerWidget {
  final DiscoveredPeer peer;
  const _ShareOptionsSheet({required this.peer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notes = ref.watch(notesProvider).maybeWhen(data: (n) => n, orElse: () => <Note>[]);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, sc) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text('Share with ${peer.name}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(syncStateProvider.notifier).shareAllNotes(peer);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('Share All', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: sc,
              itemCount: notes.length,
              itemBuilder: (_, i) {
                final note = notes[i];
                final sel  = ref.watch(selectedNotesProvider).contains(note.id);
                return CheckboxListTile(
                  title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  subtitle: Text(note.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                  value: sel,
                  onChanged: (_) => ref.read(selectedNotesProvider.notifier).toggle(note.id),
                  activeColor: AppColors.primary,
                  checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  dense: true,
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: Consumer(builder: (_, ref, __) {
                final count = ref.watch(selectedNotesProvider).length;
                return ElevatedButton.icon(
                  onPressed: count == 0 ? null : () {
                    final sel   = ref.read(selectedNotesProvider);
                    final share = notes.where((n) => sel.contains(n.id)).toList();
                    Navigator.pop(context);
                    ref.read(syncStateProvider.notifier).shareNotesWith(peer, share);
                    ref.read(selectedNotesProvider.notifier).clearAll();
                  },
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: Text(count == 0 ? 'Select notes above' : 'Share $count note${count != 1 ? 's' : ''}'),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();
  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.only(top: 12),
        itemCount: 4,
        itemBuilder: (_, __) => const SkeletonPeerCard(),
      );
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.error),
            const SizedBox(height: 14),
            const Text('Network unavailable', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(error,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center),
            ),
          ],
        ),
      );
}
