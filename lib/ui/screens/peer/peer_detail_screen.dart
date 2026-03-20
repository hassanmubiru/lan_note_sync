// lib/ui/screens/peer/peer_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../models/peer.dart';
import '../../../models/note.dart';
import '../../../providers/peers_provider.dart';
import '../../../providers/notes_provider.dart';
import '../../widgets/peer_avatar.dart';

class PeerDetailScreen extends ConsumerStatefulWidget {
  final String peerId;
  final DiscoveredPeer? peer;

  const PeerDetailScreen({super.key, required this.peerId, this.peer});

  @override
  ConsumerState<PeerDetailScreen> createState() => _PeerDetailScreenState();
}

class _PeerDetailScreenState extends ConsumerState<PeerDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseAnim.dispose();
    super.dispose();
  }

  DiscoveredPeer? get _peer {
    final peers = ref.watch(peersProvider).maybeWhen(data: (p) => p, orElse: () => <DiscoveredPeer>[]);
    final found = peers.where((p) => p.id == widget.peerId);
    return found.isNotEmpty ? found.first : widget.peer;
  }

  @override
  Widget build(BuildContext context) {
    final peer = _peer;
    final theme = Theme.of(context);
    final syncState = ref.watch(syncStateProvider);
    final isSyncing = syncState.activePeerId == widget.peerId &&
        syncState.status == SyncStatus.syncing;

    if (peer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Device')),
        body: const Center(child: Text('Device no longer available')),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _PeerHeader(peer: peer, pulseAnim: _pulseAnim),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.sync_rounded),
                tooltip: 'Full sync',
                onPressed: isSyncing ? null : () {
                  ref.read(syncStateProvider.notifier).syncWithPeer(peer);
                },
              ),
            ],
          ),

          // Connection status
          SliverToBoxAdapter(
            child: _ConnectionStatus(peer: peer, isSyncing: isSyncing),
          ),

          // Action buttons
          SliverToBoxAdapter(
            child: _ActionButtons(peer: peer, isSyncing: isSyncing),
          ),

          // Remote notes list
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Notes on this device',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
          ),

          SliverFillRemaining(
            child: _RemoteNotesList(peer: peer),
          ),
        ],
      ),
    );
  }
}

class _PeerHeader extends StatelessWidget {
  final DiscoveredPeer peer;
  final AnimationController pulseAnim;

  const _PeerHeader({required this.peer, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            peer.avatarColor.withOpacity(isDark ? 0.3 : 0.15),
            peer.avatarColor.withOpacity(0.05),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Animated avatar
            AnimatedBuilder(
              animation: pulseAnim,
              builder: (_, child) => Container(
                width: 80 + pulseAnim.value * 4,
                height: 80 + pulseAnim.value * 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: peer.avatarColor.withOpacity(0.15 * pulseAnim.value),
                ),
                child: child,
              ),
              child: PeerAvatar(peer: peer, size: 80),
            ),
            const SizedBox(height: 12),
            Text(
              peer.name,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: peer.statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(peer.host, style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  final DiscoveredPeer peer;
  final bool isSyncing;

  const _ConnectionStatus({required this.peer, required this.isSyncing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: peer.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: peer.statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          if (isSyncing)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: peer.statusColor,
              ),
            )
          else
            Icon(
              peer.status == PeerStatus.connected
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              color: peer.statusColor,
              size: 20,
            ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSyncing ? 'Syncing…' : peer.statusText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: peer.statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Last seen ${_timeAgo(peer.lastSeen)}',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const Spacer(),
          Text(
            '${peer.noteCount} notes',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _ActionButtons extends ConsumerWidget {
  final DiscoveredPeer peer;
  final bool isSyncing;

  const _ActionButtons({required this.peer, required this.isSyncing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isSyncing ? null : () {
                ref.read(syncStateProvider.notifier).syncWithPeer(peer);
              },
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Full Sync'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isSyncing ? null : () {
                ref.read(syncStateProvider.notifier).shareAllNotes(peer);
              },
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share All'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteNotesList extends ConsumerWidget {
  final DiscoveredPeer peer;
  const _RemoteNotesList({required this.peer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteMetaAsync = ref.watch(peerNoteMetaProvider(peer));
    final myNotes = ref.watch(notesProvider).maybeWhen(data: (n) => n, orElse: () => <Note>[]);
    final myNoteIds = myNotes.map((n) => n.id).toSet();

    return noteMetaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(height: 8),
            Text('Could not load notes: $e', textAlign: TextAlign.center),
          ],
        ),
      ),
      data: (notesMeta) {
        if (notesMeta.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.note_alt_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text('No notes on this device',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: notesMeta.length,
          itemBuilder: (context, index) {
            final meta = notesMeta[index];
            final id = meta['id'] as String;
            final title = meta['title'] as String? ?? 'Untitled';
            final tags = List<String>.from(meta['tags'] as List? ?? []);
            final updatedAt = DateTime.tryParse(meta['updatedAt'] as String? ?? '');
            final alreadyHave = myNoteIds.contains(id);

            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  alreadyHave ? Icons.check_circle_outline : Icons.note_outlined,
                  color: alreadyHave ? AppColors.success : AppColors.primary,
                  size: 20,
                ),
              ),
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Row(
                children: [
                  if (updatedAt != null)
                    Text(DateFormat('MMM d').format(updatedAt),
                        style: Theme.of(context).textTheme.labelSmall),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    ...tags.take(2).map((t) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '#$t',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )),
                  ],
                ],
              ),
              trailing: alreadyHave
                  ? Chip(
                      label: const Text('Synced', style: TextStyle(fontSize: 10)),
                      backgroundColor: AppColors.success.withOpacity(0.1),
                      padding: const EdgeInsets.all(0),
                    )
                  : TextButton(
                      onPressed: () {
                        ref.read(syncStateProvider.notifier).shareNotesWith(
                          peer,
                          ref
                              .read(notesProvider)
                              .maybeWhen(data: (n) => n, orElse: () => <Note>[])
                              .where((n) => n.id == id)
                              .toList(),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      child: const Text('Get', style: TextStyle(fontSize: 12)),
                    ),
            ).animate().fadeIn(
              delay: Duration(milliseconds: index * 40),
              duration: AppConstants.animationFast,
            );
          },
        );
      },
    );
  }
}
