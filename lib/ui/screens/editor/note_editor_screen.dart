// lib/ui/screens/editor/note_editor_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../models/note.dart';
import '../../../providers/notes_provider.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;
  final Note? note;
  final String? initialFolder;

  const NoteEditorScreen({super.key, this.noteId, this.note, this.initialFolder});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen>
    with TickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  late AnimationController _saveAnim;

  bool _isPreviewMode = false;
  bool _hasChanges = false;
  bool _isSaving = false;
  List<String> _tags = [];
  List<String> _images = []; // base64
  String? _folder;
  String? _color;

  Note? get _existingNote => widget.note ?? (widget.noteId != null
      ? ref.read(noteByIdProvider(widget.noteId!))
      : null);

  @override
  void initState() {
    super.initState();
    _saveAnim = AnimationController(vsync: this, duration: AppConstants.animationMedium);

    final note = _existingNote;
    if (note != null) {
      _titleController.text = note.title;
      _contentController.text = note.content;
      _tags = List.from(note.tags);
      _images = List.from(note.imageBase64);
      _folder = note.folder;
      _color = note.color;
    } else {
      _folder = widget.initialFolder;
    }

    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);
  }

  void _onChanged() => setState(() => _hasChanges = true);

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _saveAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _hasChanges) {
          final save = await _showUnsavedDialog();
          if (save == true) await _saveNote();
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: Text(
            _existingNote != null ? 'Edit Note' : 'New Note',
            style: theme.textTheme.titleMedium,
          ),
          actions: [
            // Markdown preview toggle
            IconButton(
              icon: AnimatedSwitcher(
                duration: AppConstants.animationFast,
                child: Icon(
                  _isPreviewMode ? Icons.edit_outlined : Icons.preview_outlined,
                  key: ValueKey(_isPreviewMode),
                ),
              ),
              tooltip: _isPreviewMode ? 'Edit' : 'Preview',
              onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
            ),
            // More options
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'folder',
                  child: Row(children: [
                    const Icon(Icons.folder_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(_folder != null ? 'Folder: $_folder' : 'Set folder'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'color',
                  child: Row(children: [
                    const Icon(Icons.palette_outlined, size: 18),
                    const SizedBox(width: 8),
                    const Text('Note color'),
                  ]),
                ),
                if (_existingNote != null)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppColors.error)),
                    ]),
                  ),
              ],
            ),
            // Save button
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _hasChanges ? _saveNote : null,
                icon: AnimatedBuilder(
                  animation: _saveAnim,
                  builder: (_, __) => _isSaving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                ),
                label: const Text('Save'),
                style: TextButton.styleFrom(
                  backgroundColor: _hasChanges ? AppColors.primary : Colors.grey[300],
                  foregroundColor: _hasChanges ? Colors.white : Colors.grey[600],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Note color accent bar
            if (_color != null)
              Container(
                height: 3,
                color: Color(int.parse('0xFF${_color!.replaceAll('#', '')}')),
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    TextField(
                      controller: _titleController,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: AppStrings.titleHint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        filled: false,
                        hintStyle: theme.textTheme.headlineSmall?.copyWith(
                          color: isDark ? Colors.white24 : Colors.black26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.next,
                    ),

                    // Metadata row
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: theme.colorScheme.outline),
                          const SizedBox(width: 4),
                          Text(
                            _existingNote != null
                                ? DateFormat('MMM d, y · HH:mm').format(_existingNote!.updatedAt)
                                : 'New note',
                            style: theme.textTheme.labelSmall,
                          ),
                          if (_folder != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.folder_outlined, size: 12, color: theme.colorScheme.outline),
                            const SizedBox(width: 4),
                            Text(_folder!, style: theme.textTheme.labelSmall),
                          ],
                        ],
                      ),
                    ),

                    const Divider(),
                    const SizedBox(height: 8),

                    // Content - editor or preview
                    AnimatedSwitcher(
                      duration: AppConstants.animationFast,
                      child: _isPreviewMode
                          ? _MarkdownPreview(content: _contentController.text)
                          : _MarkdownEditor(controller: _contentController),
                    ),

                    const SizedBox(height: 16),

                    // Images
                    if (_images.isNotEmpty) _ImageGrid(
                      images: _images,
                      onRemove: (i) => setState(() => _images.removeAt(i)),
                    ),

                    // Markdown toolbar (edit mode only)
                    if (!_isPreviewMode)
                      _MarkdownToolbar(
                        controller: _contentController,
                        onAddImage: _pickImage,
                      ),
                  ],
                ),
              ),
            ),

            // Tags bar at bottom
            _TagsBar(
              tags: _tags,
              onAddTag: _addTag,
              onRemoveTag: (tag) => setState(() => _tags.remove(tag)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty) {
      _titleController.text = 'Untitled';
    }

    setState(() => _isSaving = true);
    _saveAnim.forward(from: 0);

    try {
      final existing = _existingNote;
      final note = existing != null
          ? existing.copyWith(
              title: _titleController.text.trim(),
              content: _contentController.text,
              tags: _tags,
              imageBase64: _images,
              folder: _folder,
              color: _color,
              updatedAt: DateTime.now(),
              version: existing.version + 1,
            )
          : Note(
              title: _titleController.text.trim(),
              content: _contentController.text,
              tags: _tags,
              imageBase64: _images,
              folder: _folder,
              color: _color,
            );

      if (existing != null) {
        await ref.read(notesProvider.notifier).updateNote(note);
      } else {
        await ref.read(notesProvider.notifier).addNote(note);
      }

      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              const Text('Note saved'),
            ]),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<bool?> _showUnsavedDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('You have unsaved changes. Save before leaving?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Discard')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.length > AppConstants.maxImageSizeBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image too large (max 5MB)')),
          );
        }
        return;
      }

      final b64 = base64Encode(bytes);
      setState(() => _images.add(b64));
      _onChanged();
    } catch (e) {
      debugPrint('[Editor] Image pick error: $e');
    }
  }

  void _addTag(String tag) {
    final trimmed = tag.trim().toLowerCase();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed) && _tags.length < AppConstants.maxTagsPerNote) {
      setState(() => _tags.add(trimmed));
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'folder':
        _showFolderDialog();
        break;
      case 'color':
        _showColorPicker();
        break;
      case 'delete':
        _deleteNote();
        break;
    }
  }

  void _showFolderDialog() {
    final controller = TextEditingController(text: _folder);
    final folders = ref.read(foldersProvider).maybeWhen(
          data: (f) => f.keys.toList(),
          orElse: () => <String>[],
        );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Folder name',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
            ),
            if (folders.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...folders.map((f) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.folder_outlined, size: 18),
                    title: Text(f),
                    onTap: () {
                      setState(() => _folder = f);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() => _folder = controller.text.trim().isEmpty ? null : controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _showColorPicker() {
    final colors = [
      null, '#EF4444', '#F97316', '#EAB308', '#22C55E',
      '#6366F1', '#8B5CF6', '#EC4899', '#06B6D4',
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Note color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((c) => GestureDetector(
            onTap: () {
              setState(() => _color = c);
              Navigator.pop(ctx);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c != null ? Color(int.parse('0xFF${c.replaceAll('#', '')}')) : Colors.grey[200],
                shape: BoxShape.circle,
                border: Border.all(
                  color: _color == c ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: c == null ? const Icon(Icons.block, size: 18, color: Colors.grey) : null,
            ),
          )).toList(),
        ),
      ),
    );
  }

  Future<void> _deleteNote() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('This cannot be undone.'),
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
    if (confirm == true && _existingNote != null) {
      await ref.read(notesProvider.notifier).deleteNote(_existingNote!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _MarkdownEditor extends StatelessWidget {
  final TextEditingController controller;
  const _MarkdownEditor({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
      decoration: InputDecoration(
        hintText: AppStrings.contentHint,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        fillColor: Colors.transparent,
        filled: false,
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.outline,
          height: 1.6,
        ),
      ),
      maxLines: null,
      keyboardType: TextInputType.multiline,
      minLines: 10,
    );
  }
}

class _MarkdownPreview extends StatelessWidget {
  final String content;
  const _MarkdownPreview({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (content.isEmpty) {
      return Center(
        child: Text(
          'Nothing to preview yet…',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
        ),
      );
    }
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
        h1: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        h2: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        h3: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        code: TextStyle(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          fontSize: 13,
        ),
        blockquoteDecoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(4), bottomRight: Radius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAddImage;

  const _MarkdownToolbar({required this.controller, required this.onAddImage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ToolbarButton('B', tooltip: 'Bold', onTap: () => _wrap(controller, '**', '**')),
            _ToolbarButton('I', tooltip: 'Italic', onTap: () => _wrap(controller, '_', '_'), italic: true),
            _ToolbarButton('`', tooltip: 'Code', onTap: () => _wrap(controller, '`', '`'), mono: true),
            const VerticalDivider(width: 16),
            _ToolbarIconButton(Icons.format_list_bulleted, 'Bullet list',
                onTap: () => _prependLine(controller, '- ')),
            _ToolbarIconButton(Icons.format_list_numbered, 'Numbered list',
                onTap: () => _prependLine(controller, '1. ')),
            _ToolbarIconButton(Icons.format_quote, 'Quote',
                onTap: () => _prependLine(controller, '> ')),
            const VerticalDivider(width: 16),
            _ToolbarIconButton(Icons.link, 'Link',
                onTap: () => _insertLink(controller)),
            _ToolbarIconButton(Icons.image_outlined, 'Image', onTap: onAddImage),
            _ToolbarIconButton(Icons.horizontal_rule, 'Divider',
                onTap: () => _insertText(controller, '\n---\n')),
          ],
        ),
      ),
    );
  }

  void _wrap(TextEditingController c, String start, String end) {
    final sel = c.selection;
    if (!sel.isValid) return;
    final selected = c.text.substring(sel.start, sel.end);
    final newText = c.text.replaceRange(sel.start, sel.end, '$start$selected$end');
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + start.length + selected.length + end.length),
    );
  }

  void _prependLine(TextEditingController c, String prefix) {
    final pos = c.selection.baseOffset;
    final lineStart = c.text.lastIndexOf('\n', pos - 1) + 1;
    final newText = c.text.replaceRange(lineStart, lineStart, prefix);
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
  }

  void _insertText(TextEditingController c, String text) {
    final pos = c.selection.isValid ? c.selection.baseOffset : c.text.length;
    final newText = c.text.replaceRange(pos, pos, text);
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + text.length),
    );
  }

  void _insertLink(TextEditingController c) {
    final sel = c.selection;
    if (!sel.isValid) return;
    final selected = sel.start == sel.end ? 'link text' : c.text.substring(sel.start, sel.end);
    _wrap(c, '[$selected](', ')');
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool italic, mono;

  const _ToolbarButton(
    this.label, {
    required this.tooltip,
    required this.onTap,
    this.italic = false,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              fontFamily: mono ? 'monospace' : null,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarIconButton(this.icon, this.tooltip, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _TagsBar extends StatefulWidget {
  final List<String> tags;
  final Function(String) onAddTag;
  final Function(String) onRemoveTag;

  const _TagsBar({
    required this.tags,
    required this.onAddTag,
    required this.onRemoveTag,
  });

  @override
  State<_TagsBar> createState() => _TagsBarState();
}

class _TagsBarState extends State<_TagsBar> {
  bool _adding = false;
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.tag, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...widget.tags.asMap().entries.map((e) {
                    final idx = e.key % AppColors.tagColors.length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(e.value),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: AppColors.tagColors[idx],
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: AppColors.tagColors[idx].withOpacity(0.12),
                        deleteIcon: const Icon(Icons.close, size: 12),
                        deleteIconColor: AppColors.tagColors[idx],
                        onDeleted: () => widget.onRemoveTag(e.value),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        side: BorderSide.none,
                      ),
                    );
                  }),
                  if (_adding)
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'Tag name…',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (val) {
                          widget.onAddTag(val);
                          _ctrl.clear();
                          setState(() => _adding = false);
                        },
                        onEditingComplete: () => setState(() => _adding = false),
                      ),
                    ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _adding = true),
            child: Icon(Icons.add_circle_outline, size: 18, color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  final List<String> images;
  final Function(int) onRemove;

  const _ImageGrid({required this.images, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                base64Decode(images[index]),
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => onRemove(index),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
