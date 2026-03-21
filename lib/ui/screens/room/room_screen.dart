// lib/ui/screens/room/room_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../models/peer.dart';
import '../../../models/room.dart';
import '../../../providers/room_provider.dart';
import '../../../providers/notes_provider.dart';
import '../../../providers/peers_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/security_badge_row.dart';

class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final roomState = ref.watch(roomProvider);
    final peers = ref.watch(peersProvider).maybeWhen(data: (p) => p, orElse: () => <DiscoveredPeer>[]);
    final notes = ref.watch(notesProvider).maybeWhen(data: (n) => n, orElse: () => <DiscoveredPeer>[]);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: _RoomHeroHeader(room: roomState.currentRoom),
              collapseMode: CollapseMode.parallax,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showRoomInfo(context, roomState.currentRoom),
              ),
            ],
          ),

          // Current room status
          SliverToBoxAdapter(
            child: roomState.currentRoom != null
                ? _ActiveRoomCard(
                    room: roomState.currentRoom!,
                    peerCount: peers.length,
                    noteCount: notes.length,
                  )
                : _NoRoomCard(),
          ),

          // Live peer list in room
          if (peers.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '${peers.length} teammate${peers.length != 1 ? 's' : ''} in this room',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _RoomPeerTile(peer: peers[i])
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: i * 60)),
                childCount: peers.length,
              ),
            ),
          ],

          // Pinned notes in room
          if (roomState.currentRoom != null && roomState.pinnedNotes(notes).isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(children: [
                  const Icon(Icons.push_pin, size: 16, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text(
                    'Pinned to this room',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final n = roomState.pinnedNotes(notes)[i];
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.push_pin, size: 16, color: AppColors.warning),
                    ),
                    title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(n.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => context.push('/note/${n.id}', extra: n),
                    trailing: IconButton(
                      icon: const Icon(Icons.push_pin_outlined, size: 16),
                      tooltip: 'Unpin from room',
                      onPressed: () => ref.read(roomProvider.notifier).unpinNote(n.id),
                    ),
                  );
                },
                childCount: roomState.pinnedNotes(notes).length,
              ),
            ),
          ],

          // All shareable notes
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Share a note to the room',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (peers.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _shareAllToRoom(context, ref, peers),
                      icon: const Icon(Icons.share, size: 14),
                      label: const Text('Share All'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    ),
                ],
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final note = notes[i];
                return CheckboxListTile(
                  dense: true,
                  value: roomState.currentRoom?.pinnedNoteIds.contains(note.id) ?? false,
                  onChanged: (v) {
                    if (v == true) {
                      ref.read(roomProvider.notifier).pinNote(note.id);
                    } else {
                      ref.read(roomProvider.notifier).unpinNote(note.id);
                    }
                  },
                  title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(note.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                  activeColor: AppColors.primary,
                  checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                );
              },
              childCount: notes.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _showRoomInfo(BuildContext context, Room? room) {
    if (room == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Text(room.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Flexible(child: Text(room.displayName)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WiFi SSID: ${room.ssid}'),
            const SizedBox(height: 4),
            Text('Room ID: ${room.id}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 4),
            Text('Joined: ${room.joinedAt.toLocal().toString().substring(0, 16)}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _shareAllToRoom(BuildContext context, WidgetRef ref, List peers) {
    if (peers.isEmpty) return;
    final notes = ref.read(notesProvider).maybeWhen(data: (n) => n, orElse: () => <Note>[]);
    for (final peer in peers) {
      ref.read(syncStateProvider.notifier).shareNotesWith(peer, notes);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing ${notes.length} notes with ${peers.length} peers')),
    );
  }
}

class _RoomHeroHeader extends StatelessWidget {
  final Room? room;
  const _RoomHeroHeader({required this.room});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: room != null
              ? [AppColors.secondary.withOpacity(0.3), AppColors.primary.withOpacity(0.15)]
              : [Colors.grey.withOpacity(0.2), Colors.grey.withOpacity(0.05)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Text(
              room?.emoji ?? '📡',
              style: const TextStyle(fontSize: 48),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 8),
            Text(
              room != null ? room!.displayName : 'No Room Detected',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (room != null)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6,
                        decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Auto-joined', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveRoomCard extends StatelessWidget {
  final Room room;
  final int peerCount, noteCount;
  const _ActiveRoomCard({required this.room, required this.peerCount, required this.noteCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Stat(icon: Icons.people_outline, value: '$peerCount', label: 'Teammates'),
                  ),
                  Container(width: 1, height: 40, color: theme.dividerColor),
                  Expanded(
                    child: _Stat(icon: Icons.note_outlined, value: '$noteCount', label: 'Shared Notes'),
                  ),
                  Container(width: 1, height: 40, color: theme.dividerColor),
                  Expanded(
                    child: _Stat(icon: Icons.wifi, value: '🟢', label: 'Live Sync'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _NoRoomCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.wifi_off, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No room detected',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Connect to a WiFi network to auto-join\na collaboration room with nearby teammates.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomPeerTile extends StatelessWidget {
  final DiscoveredPeer peer;
  const _RoomPeerTile({required this.peer});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: peer.avatarColor,
        child: Text(peer.initials,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
      title: Text(peer.name),
      subtitle: Row(children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: peer.statusColor, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(peer.statusText, style: const TextStyle(fontSize: 11)),
      ]),
      trailing: Text('${peer.noteCount} notes',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
    );
  }
}
