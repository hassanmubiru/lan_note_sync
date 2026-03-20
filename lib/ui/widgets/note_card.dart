// lib/ui/widgets/note_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final VoidCallback onPin;

  const NoteCard({
    super.key,
    required this.note,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onPin,
  });

  Color? get _accent => note.color != null
      ? Color(int.parse('0xFF${note.color!.replaceAll('#', '')}'))
      : null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: Key('note-${note.id}'),
      direction: DismissDirection.endToStart,
      background: _DeleteBackground(),
      confirmDismiss: (_) async { onDelete(); return false; },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: AppConstants.animationFast,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(isDark ? 0.15 : 0.07)
                  : isDark ? const Color(0xFF1A2235) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.6)
                    : _accent?.withOpacity(0.5) ??
                      (isDark ? const Color(0xFF263048) : const Color(0xFFE8ECF4)),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(
                      color: AppColors.primary.withOpacity(0.12),
                      blurRadius: 16, offset: const Offset(0, 4))]
                  : [BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                      blurRadius: 12, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Accent bar
                if (_accent != null)
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(note: note, isSelected: isSelected, onPin: onPin),
                      if (note.preview.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        _Preview(text: note.preview, isDark: isDark),
                      ],
                      if (note.imageBase64.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _ImageHint(count: note.imageBase64.length),
                      ],
                      const SizedBox(height: 10),
                      _Footer(note: note),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.error.withOpacity(0), AppColors.error],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            SizedBox(height: 3),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _Header extends StatelessWidget {
  final Note note;
  final bool isSelected;
  final VoidCallback onPin;
  const _Header({required this.note, required this.isSelected, required this.onPin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            note.title.isEmpty ? 'Untitled' : note.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.3,
              letterSpacing: -0.1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        if (isSelected)
          const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
        else
          GestureDetector(
            onTap: onPin,
            child: Icon(
              note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              size: 15,
              color: note.isPinned
                  ? AppColors.tertiary
                  : Theme.of(context).colorScheme.outline.withOpacity(0.35),
            ),
          ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  final String text;
  final bool isDark;
  const _Preview({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          height: 1.5,
          color: isDark ? Colors.white38 : Colors.grey[500],
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
}

class _ImageHint extends StatelessWidget {
  final int count;
  const _ImageHint({required this.count});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 11, color: Colors.grey[500]),
          const SizedBox(width: 3),
          Text(
            '$count image${count > 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      );
}

class _Footer extends StatelessWidget {
  final Note note;
  const _Footer({required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // Tags
        if (note.tags.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: note.tags.take(3).map((tag) {
                  final idx = tag.codeUnits.fold(0, (s, c) => s + c) % AppColors.tagColors.length;
                  return _TagPill(tag: tag, color: AppColors.tagColors[idx]);
                }).toList(),
              ),
            ),
          )
        else
          const Spacer(),

        // Date
        Text(
          _fmt(note.updatedAt),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline.withOpacity(0.7),
          ),
        ),

        // Indicators
        if (note.sourceDeviceId != null) ...[
          const SizedBox(width: 6),
          Icon(Icons.device_hub_rounded, size: 10,
              color: AppColors.secondary.withOpacity(0.6)),
        ],
        if (note.isMarkdown) ...[
          const SizedBox(width: 5),
          Text('MD', style: TextStyle(
            fontSize: 8, fontWeight: FontWeight.w800,
            color: AppColors.primary.withOpacity(0.5),
            letterSpacing: 0.5,
          )),
        ],
      ],
    );
  }

  String _fmt(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60)  return 'just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    if (diff.inDays    < 7)   return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _TagPill extends StatelessWidget {
  final String tag;
  final Color color;
  const _TagPill({required this.tag, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 5),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          tag,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      );
}
