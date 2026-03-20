// lib/ui/screens/voice/voice_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../services/voice/voice_service.dart';
import '../../../providers/voice_provider.dart';
import '../../../providers/purchase_provider.dart';

class VoiceScreen extends ConsumerStatefulWidget {
  final void Function(String transcript)? onTranscriptDone;
  const VoiceScreen({super.key, this.onTranscriptDone});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voiceState = ref.watch(voiceProvider);
    final purchaseStatus = ref.watch(purchaseProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Voice to Note'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: const Text('🎙️ Local AI', style: TextStyle(fontSize: 11)),
              backgroundColor: AppColors.success.withOpacity(0.1),
              side: const BorderSide(color: AppColors.success, width: 0.5),
            ),
          ),
        ],
      ),
      body: !purchaseStatus.canUseVoice
          ? _PaywallView()
          : Column(
              children: [
                // Privacy badge
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: AppColors.primary.withOpacity(0.06),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 13, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Speech processed 100% on-device • Never sent to servers',
                        style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Waveform visualizer
                      StreamBuilder<List<double>>(
                        stream: ref.read(voiceServiceProvider).waveformStream,
                        builder: (ctx, snap) {
                          final bars = snap.data ?? List.filled(20, 0.1);
                          return _WaveformWidget(
                            bars: bars,
                            isActive: voiceState.status == VoiceStatus.listening,
                            pulseAnim: _pulseCtrl,
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Status label
                      _StatusLabel(status: voiceState.status),

                      const SizedBox(height: 24),

                      // Live transcript
                      if (voiceState.currentTranscript.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                          ),
                          constraints: const BoxConstraints(maxHeight: 160),
                          child: SingleChildScrollView(
                            child: Text(
                              voiceState.currentTranscript,
                              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                            ),
                          ),
                        ).animate().fadeIn(),

                      const SizedBox(height: 40),

                      // Record button
                      _RecordButton(
                        status: voiceState.status,
                        pulseAnim: _pulseCtrl,
                        onTap: () => _handleRecordTap(context, ref),
                      ),

                      const SizedBox(height: 16),

                      // Secondary actions
                      if (voiceState.status == VoiceStatus.listening)
                        TextButton(
                          onPressed: () => ref.read(voiceProvider.notifier).cancel(),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.error)),
                        ),

                      if (voiceState.status == VoiceStatus.done &&
                          voiceState.currentTranscript.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: voiceState.currentTranscript));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Copied to clipboard')),
                                    );
                                  },
                                  icon: const Icon(Icons.copy, size: 14),
                                  label: const Text('Copy'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    widget.onTranscriptDone?.call(voiceState.currentTranscript);
                                    Navigator.of(context).pop(voiceState.currentTranscript);
                                  },
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('Add to Note'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _handleRecordTap(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(voiceProvider.notifier);
    final status = ref.read(voiceProvider).status;

    if (status == VoiceStatus.idle || status == VoiceStatus.done || status == VoiceStatus.error) {
      await notifier.startListening();
    } else if (status == VoiceStatus.listening) {
      await notifier.stopListening();
    }
  }
}

// ─── Waveform widget ──────────────────────────────────────────────────────────

class _WaveformWidget extends StatelessWidget {
  final List<double> bars;
  final bool isActive;
  final AnimationController pulseAnim;

  const _WaveformWidget({required this.bars, required this.isActive, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => SizedBox(
        height: 80,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: bars.asMap().entries.map((e) {
            final idx = e.key;
            final val = e.value;
            final animatedHeight = isActive
                ? max(4.0, val * 70)
                : 4.0 + sin(idx * 0.5 + pulseAnim.value * pi) * 2;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: animatedHeight,
              decoration: BoxDecoration(
                color: isActive
                    ? Color.lerp(AppColors.primary, AppColors.neon, val)
                    : AppColors.primary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Status label ─────────────────────────────────────────────────────────────

class _StatusLabel extends StatelessWidget {
  final VoiceStatus status;
  const _StatusLabel({required this.status});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    switch (status) {
      case VoiceStatus.idle:
        label = 'Tap mic to record'; color = Colors.grey;
        break;
      case VoiceStatus.initializing:
        label = 'Initializing...'; color = AppColors.tertiary;
        break;
      case VoiceStatus.listening:
        label = AppStrings.voiceListening; color = AppColors.error;
        break;
      case VoiceStatus.processing:
        label = AppStrings.voiceProcessing; color = AppColors.warning;
        break;
      case VoiceStatus.done:
        label = AppStrings.voiceDone; color = AppColors.success;
        break;
      case VoiceStatus.error:
        label = 'Error — tap to retry'; color = AppColors.error;
        break;
    }

    return Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15),
    ).animate(key: ValueKey(status)).fadeIn().slideY(begin: 0.2);
  }
}

// ─── Record button ────────────────────────────────────────────────────────────

class _RecordButton extends StatelessWidget {
  final VoiceStatus status;
  final AnimationController pulseAnim;
  final VoidCallback onTap;

  const _RecordButton({required this.status, required this.pulseAnim, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isListening = status == VoiceStatus.listening;
    final isLoading = status == VoiceStatus.initializing || status == VoiceStatus.processing;

    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, child) {
        final scale = isListening ? 1.0 + pulseAnim.value * 0.08 : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppConstants.animationMedium,
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isListening ? AppColors.error : AppColors.primary,
            boxShadow: [
              BoxShadow(
                color: (isListening ? AppColors.error : AppColors.primary).withOpacity(0.4),
                blurRadius: isListening ? 24 : 12,
                spreadRadius: isListening ? 4 : 0,
              ),
            ],
          ),
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
              : Icon(
                  isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 36,
                ),
        ),
      ),
    );
  }
}

// ─── Paywall view ─────────────────────────────────────────────────────────────

class _PaywallView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎙️', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text('Voice Transcription',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Unlock local on-device speech-to-text.\nNo internet required. 95%+ accuracy.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/monetization'),
              child: const Text('Unlock — \$2 Lifetime'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
