// lib/ui/screens/conflict/conflict_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../models/note.dart';
import '../../../providers/notes_provider.dart';
import '../../../services/sync/sync_service.dart';
import '../../../providers/peers_provider.dart';

class ConflictScreenArgs {
  final Note localNote;
  final Note remoteNote;
  final String peerName;

  const ConflictScreenArgs({
    required this.localNote,
    required this.remoteNote,
    required this.peerName,
  });
}

class ConflictScreen extends ConsumerStatefulWidget {
  final ConflictScreenArgs args;
  const ConflictScreen({super.key, required this.args});

  @override
  ConsumerState<ConflictScreen> createState() => _ConflictScreenState();
}

class _ConflictScreenState extends ConsumerState<ConflictScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _mergedTitleCtrl;
  late final TextEditingController _mergedContentCtrl;

  _ConflictResolution _resolution = _ConflictResolution.undecided;
  bool _showMergeEditor = false;

  Note get local => widget.args.localNote;
  Note get remote => widget.args.remoteNote;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _mergedTitleCtrl = TextEditingController(text: local.title);
    _mergedContentCtrl = TextEditingController(text: local.content);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mergedTitleCtrl.dispose();
    _mergedContentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber, size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Conflict',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                local.title,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Info banner
          _ConflictBanner(
            localTime: local.updatedAt,
            remoteTime: remote.updatedAt,
            peerName: widget.args.peerName,
          ).animate().slideY(begin: -0.2).fadeIn(),

          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'My Version'),
              Tab(text: 'Their Version'),
              Tab(text: 'Merge'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _NoteVersionView(note: local, label: 'Mine', color: AppColors.primary),
                _NoteVersionView(note: remote, label: widget.args.peerName, color: AppColors.secondary),
                _MergeView(
                  local: local,
                  remote: remote,
                  titleCtrl: _mergedTitleCtrl,
                  contentCtrl: _mergedContentCtrl,
                  showEditor: _showMergeEditor,
                  onToggleEditor: () => setState(() => _showMergeEditor = !_showMergeEditor),
                  onUseLocal: () => setState(() {
                    _mergedTitleCtrl.text = local.title;
                    _mergedContentCtrl.text = local.content;
                  }),
                  onUseRemote: () => setState(() {
                    _mergedTitleCtrl.text = remote.title;
                    _mergedContentCtrl.text = remote.content;
                  }),
                ),
              ],
            ),
          ),

          // Resolution buttons
          _ResolutionBar(
            resolution: _resolution,
            onKeepMine: () => _resolve(useLocal: true),
            onKeepTheirs: () => _resolve(useLocal: false),
            onMerge: () => _resolveWithMerge(),
          ),
        ],
      ),
    );
  }

  Future<void> _resolve({required bool useLocal}) async {
    final syncService = ref.read(syncServiceProvider);
    await syncService.resolveConflict(local, remote, useLocal: useLocal);
    await ref.read(notesProvider.notifier).refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 16),
            const SizedBox(width: 8),
            Text(useLocal ? 'Kept your version' : 'Used their version'),
          ]),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _resolveWithMerge() async {
    if (_mergedTitleCtrl.text.trim().isEmpty) return;
    final syncService = ref.read(syncServiceProvider);
    await syncService.mergeConflict(
      local,
      remote,
      mergedTitle: _mergedTitleCtrl.text.trim(),
      mergedContent: _mergedContentCtrl.text,
    );
    await ref.read(notesProvider.notifier).refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.merge_type, color: AppColors.success, size: 16),
            SizedBox(width: 8),
            Text('Notes merged successfully'),
          ]),
        ),
      );
      Navigator.of(context).pop();
    }
  }
}

class _ConflictBanner extends StatelessWidget {
  final DateTime localTime, remoteTime;
  final String peerName;

  const _ConflictBanner({
    required this.localTime,
    required this.remoteTime,
    required this.peerName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('MMM d, HH:mm');

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Both versions were edited independently',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _versionChip(context, 'Mine', fmt.format(localTime), AppColors.primary),
              const SizedBox(width: 8),
              Icon(Icons.compare_arrows, size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: 8),
              _versionChip(context, peerName, fmt.format(remoteTime), AppColors.secondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _versionChip(BuildContext ctx, String name, String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          Text(time, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}

class _NoteVersionView extends StatelessWidget {
  final Note note;
  final String label;
  final Color color;

  const _NoteVersionView({required this.note, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(note.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          // Tags
          if (note.tags.isNotEmpty)
            Wrap(
              spacing: 6,
              children: note.tags.map((t) => Chip(
                label: Text(t, style: const TextStyle(fontSize: 11)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.all(0),
              )).toList(),
            ),

          const Divider(height: 20),

          // Content
          MarkdownBody(
            data: note.content,
            styleSheet: MarkdownStyleSheet.fromTheme(theme),
          ),
        ],
      ),
    );
  }
}

class _MergeView extends StatelessWidget {
  final Note local, remote;
  final TextEditingController titleCtrl, contentCtrl;
  final bool showEditor;
  final VoidCallback onToggleEditor, onUseLocal, onUseRemote;

  const _MergeView({
    required this.local,
    required this.remote,
    required this.titleCtrl,
    required this.contentCtrl,
    required this.showEditor,
    required this.onToggleEditor,
    required this.onUseLocal,
    required this.onUseRemote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Quick pick buttons
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUseLocal,
                  icon: const Icon(Icons.arrow_back, size: 14),
                  label: const Text('Use Mine', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUseRemote,
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Use Theirs', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(showEditor ? Icons.preview : Icons.edit_outlined, size: 18),
                tooltip: showEditor ? 'Preview' : 'Edit',
                onPressed: onToggleEditor,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Merged editor/preview
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: false,
                  ),
                ),
                const Divider(),
                if (showEditor)
                  TextField(
                    controller: contentCtrl,
                    maxLines: null,
                    minLines: 10,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                    decoration: const InputDecoration(
                      hintText: 'Content…',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: false,
                    ),
                  )
                else
                  ListenableBuilder(
                    listenable: contentCtrl,
                    builder: (_, __) => MarkdownBody(
                      data: contentCtrl.text,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResolutionBar extends StatelessWidget {
  final _ConflictResolution resolution;
  final VoidCallback onKeepMine, onKeepTheirs, onMerge;

  const _ResolutionBar({
    required this.resolution,
    required this.onKeepMine,
    required this.onKeepTheirs,
    required this.onMerge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onKeepMine,
              child: const Text('Keep Mine'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onMerge,
              icon: const Icon(Icons.merge_type, size: 16),
              label: const Text('Save Merge'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: onKeepTheirs,
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondary),
              child: const Text('Keep Theirs'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ConflictResolution { undecided, useLocal, useRemote, merged }
