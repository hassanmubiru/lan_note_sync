// lib/ui/widgets/skeleton_loader.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class _SkeletonBox extends StatelessWidget {
  final double width, height;
  final BorderRadius? borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black12,
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
          duration: 1200.ms,
          color: isDark ? Colors.white12 : Colors.black12,
        );
  }
}

class SkeletonNoteCard extends StatelessWidget {
  const SkeletonNoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonBox(width: 180, height: 16, borderRadius: BorderRadius.circular(8)),
              const Spacer(),
              _SkeletonBox(width: 40, height: 12, borderRadius: BorderRadius.circular(4)),
            ],
          ),
          const SizedBox(height: 10),
          _SkeletonBox(width: double.infinity, height: 12, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 6),
          _SkeletonBox(width: 200, height: 12, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 12),
          Row(
            children: [
              _SkeletonBox(width: 50, height: 18, borderRadius: BorderRadius.circular(9)),
              const SizedBox(width: 6),
              _SkeletonBox(width: 60, height: 18, borderRadius: BorderRadius.circular(9)),
              const Spacer(),
              _SkeletonBox(width: 55, height: 11, borderRadius: BorderRadius.circular(4)),
            ],
          ),
        ],
      ),
    );
  }
}

class SkeletonPeerCard extends StatelessWidget {
  const SkeletonPeerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          _SkeletonBox(width: 52, height: 52, borderRadius: BorderRadius.circular(26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 120, height: 14, borderRadius: BorderRadius.circular(7)),
                const SizedBox(height: 8),
                _SkeletonBox(width: 80, height: 11, borderRadius: BorderRadius.circular(5)),
                const SizedBox(height: 6),
                _SkeletonBox(width: 60, height: 10, borderRadius: BorderRadius.circular(5)),
              ],
            ),
          ),
          _SkeletonBox(width: 70, height: 30, borderRadius: BorderRadius.circular(8)),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1400.ms);
  }
}
