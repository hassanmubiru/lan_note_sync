// lib/ui/widgets/live_cursor.dart
//
// Live Cursor Widget — renders remote peer typing positions in the note editor.
//
// Usage:
//   Stack(children: [
//     TextField(controller: _ctrl, ...),
//     ...cursors.entries.map((e) => LiveCursorOverlay(
//       cursor: e.value,
//       textEditingController: _ctrl,
//       textStyle: bodyStyle,
//     )),
//   ])

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/sync/cursor_service.dart';

// ─── Live cursor overlay ──────────────────────────────────────────────────────

class LiveCursorOverlay extends StatefulWidget {
  final PeerCursor cursor;
  final TextEditingController textController;
  final TextStyle textStyle;
  final double lineHeight;

  const LiveCursorOverlay({
    super.key,
    required this.cursor,
    required this.textController,
    required this.textStyle,
    this.lineHeight = 22,
  });

  @override
  State<LiveCursorOverlay> createState() => _LiveCursorOverlayState();
}

class _LiveCursorOverlayState extends State<LiveCursorOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = _getOffsetForCursor();
    if (pos == null) return const SizedBox.shrink();

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: widget.cursor.color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              widget.cursor.deviceName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ).animate().fadeIn(duration: 200.ms),

          // Blinking cursor line
          AnimatedBuilder(
            animation: _blinkCtrl,
            builder: (_, __) => Opacity(
              opacity: _blinkCtrl.value,
              child: Container(
                width: 2,
                height: widget.lineHeight,
                color: widget.cursor.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Approximate pixel offset for a text cursor at `widget.cursor.offset`
  Offset? _getOffsetForCursor() {
    final text   = widget.textController.text;
    final offset = widget.cursor.offset.clamp(0, text.length);
    if (text.isEmpty) return const Offset(0, 0);

    final substr  = text.substring(0, offset);
    final lines   = substr.split('\n');
    final lineIdx = lines.length - 1;
    final colIdx  = lines.last.length;

    // Rough approximation using charWidth × col + lineHeight × line
    // For pixel-perfect placement, use TextPainter (more expensive)
    final charWidth = (widget.textStyle.fontSize ?? 14) * 0.55;
    final x = colIdx * charWidth;
    final y = lineIdx * widget.lineHeight;

    return Offset(x, y);
  }
}

// ─── Cursor presence dot ─────────────────────────────────────────────────────

/// Small colored dot shown next to a peer's name in the peer list
/// when they are currently editing a shared note.
class CursorPresenceDot extends StatelessWidget {
  final Color color;
  const CursorPresenceDot({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1, end: 1.5, duration: 700.ms);
  }
}

// ─── Live typing badge ────────────────────────────────────────────────────────

/// Shows "🟢 Typing now" badge on peer cards when they are live-editing.
class LiveTypingBadge extends StatelessWidget {
  final String peerName;
  final Color color;

  const LiveTypingBadge({
    super.key,
    required this.peerName,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CursorPresenceDot(color: color),
          const SizedBox(width: 5),
          Text(
            'Typing now',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Cursor stream builder ────────────────────────────────────────────────────

/// Convenience widget that subscribes to the cursor service and rebuilds
/// whenever peer cursor positions change.
class LiveCursorStreamBuilder extends StatelessWidget {
  final Stream<Map<String, PeerCursor>> stream;
  final Widget Function(BuildContext, Map<String, PeerCursor>) builder;

  const LiveCursorStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, PeerCursor>>(
      stream: stream,
      initialData: const {},
      builder: (ctx, snap) => builder(ctx, snap.data ?? {}),
    );
  }
}
