// lib/ui/screens/home/my_notes_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../models/note.dart';
import '../../../providers/notes_provider.dart';
import '../../../providers/peers_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/note_card.dart';
import '../../widgets/skeleton_loader.dart';

class MyNotesTab extends ConsumerStatefulWidget {
  const MyNotesTab({super.key});

  @override
  ConsumerState<MyNotesTab> createState() => _MyNotesTabState();
}

class _MyNotesTabState extends ConsumerState<MyNotesTab> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(sortedNotesProvider);
    final selectedIds = ref.watch(selectedNotesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(notesProvider.notifier).refresh(),
      color: AppColors.primary,
      child: notesAsync.when(
        loading: () => const _SkeletonList(),
        error:   (e, _) => _ErrorState(error: e.toString()),
        data: (notes) {
          if (notes.isEmpty) {
            return EmptyState(
              icon: Icons.note_alt_outlined,
              title: 'No notes yet',
              subtitle: 'Tap + to create your first note',
              actionLabel: 'Create Note',
              onAction: () => context.push('/note/new'),
            );
          }

          return Column(
            children: [
              if (selectedIds.isNotEmpty) _SelectionBar(count: selectedIds.length),
              _SortBar(noteCount: notes.length),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return NoteCard(
                      note: note,
                      isSelected: selectedIds.contains(note.id),
                      onTap: () {
                        if (selectedIds.isNotEmpty) {
                          ref.read(selectedNotesProvider.notifier).toggle(note.id);
                        } else {
                          context.push('/note/${note.id}', extra: note);
                        }
                      },
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        ref.read(selectedNotesProvider.notifier).toggle(note.id);
                      },
                      onDelete: () => _deleteNote(context, note),
                      onPin:    () => ref.read(notesProvider.notifier).togglePin(note.id),
                    ).animate().fadeIn(
                      duration: AppConstants.animationFast,
                      delay: Duration(milliseconds: index * 30),
                    ).slideY(begin: 0.08, end: 0);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteNote(BuildContext context, Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Delete "${note.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(notesProvider.notifier).deleteNote(note.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => ref.read(notesProvider.notifier).addNote(note),
            ),
          ),
        );
      }
    }
  }
}

// ─── Sort bar ─────────────────────────────────────────────────────────────────

class _SortBar extends ConsumerWidget {
  final int noteCount;
  const _SortBar({required this.noteCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort  = ref.watch(noteSortProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '$noteCount note${noteCount != 1 ? 's' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          PopupMenuButton<NoteSort>(
            initialValue: sort,
            onSelected: (s) => ref.read(noteSortProvider.notifier).state = s,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  _sortLabel(sort),
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: NoteSort.updatedDesc, child: Text('Last Modified')),
              PopupMenuItem(value: NoteSort.createdDesc, child: Text('Date Created')),
              PopupMenuItem(value: NoteSort.titleAsc,    child: Text('Title A→Z')),
              PopupMenuItem(value: NoteSort.titleDesc,   child: Text('Title Z→A')),
            ],
          ),
        ],
      ),
    );
  }

  String _sortLabel(NoteSort sort) {
    switch (sort) {
      case NoteSort.updatedDesc: return 'Modified';
      case NoteSort.createdDesc: return 'Created';
      case NoteSort.titleAsc:   return 'A→Z';
      case NoteSort.titleDesc:  return 'Z→A';
      default:                   return 'Sort';
    }
  }
}

// ─── Selection bar ────────────────────────────────────────────────────────────

class _SelectionBar extends ConsumerWidget {
  final int count;
  const _SelectionBar({required this.count});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            '$count selected',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white, fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _shareSelected(context, ref),
            icon: const Icon(Icons.share, color: Colors.white, size: 16),
            label: const Text('Share', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => ref.read(selectedNotesProvider.notifier).clearAll(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _shareSelected(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _PeerPickerSheet(),
    );
  }
}

// ─── Peer picker sheet ────────────────────────────────────────────────────────

class _PeerPickerSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peers      = ref.watch(peersProvider).maybeWhen(data: (p) => p, orElse: () => <DiscoveredPeer>[]);
    final selectedIds = ref.watch(selectedNotesProvider);
    final theme      = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Share with…', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          if (peers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.wifi_off, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    const Text('No nearby devices found'),
                  ],
                ),
              ),
            )
          else
            ...peers.map((peer) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: peer.avatarColor,
                    child: Text(peer.initials,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(peer.name),
                  subtitle: Text('${peer.noteCount} notes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    final notes = ref
                        .read(notesProvider)
                        .maybeWhen(data: (n) => n, orElse: () => <Note>[])
                        .where((n) => selectedIds.contains(n.id))
                        .toList();
                    ref.read(syncStateProvider.notifier).shareNotesWith(peer, notes);
                    ref.read(selectedNotesProvider.notifier).clearAll();
                  },
                )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();
  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: 6,
        itemBuilder: (_, __) => const SkeletonNoteCard(),
      );
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Something went wrong',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(error,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      );
}
