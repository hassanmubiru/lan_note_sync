// lib/ui/screens/ar_whiteboard/ar_peer_targeting_screen.dart
//
// AR Peer Targeting — point camera at peer's QR code to initiate sync.
// Combines MobileScanner with an AR-feel glassmorphism HUD overlay.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../models/peer.dart';
import '../../../services/ar_peer_targeting.dart';
import '../../../providers/peers_provider.dart';
import '../../../ui/widgets/e2ee_badge.dart';

class ArPeerTargetingScreen extends ConsumerStatefulWidget {
  const ArPeerTargetingScreen({super.key});

  @override
  ConsumerState<ArPeerTargetingScreen> createState() =>
      _ArPeerTargetingScreenState();
}

class _ArPeerTargetingScreenState extends ConsumerState<ArPeerTargetingScreen>
    with SingleTickerProviderStateMixin {
  late final ArPeerTargeting _ar;
  late final AnimationController _scanCtrl;

  ArScanResult _scanResult = const ArScanResult(status: ArScanStatus.idle);
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _ar = ArPeerTargeting();
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();

    _ar.resultStream.listen((result) {
      if (!mounted) return;
      setState(() => _scanResult = result);

      if (result.status == ArScanStatus.locked) {
        HapticFeedback.heavyImpact();
      }
    });

    _ar.startScanning();
    _started = true;
  }

  @override
  void dispose() {
    _ar.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera feed
          MobileScanner(
            controller: _ar.controller,
            onDetect: _ar.onDetect,
          ),

          // AR overlay
          _ArOverlay(
            scanCtrl: _scanCtrl,
            result: _scanResult,
          ),

          // HUD: top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _TopHud(
                onClose: () => context.pop(),
                status: _scanResult.status,
              ),
            ),
          ),

          // HUD: bottom action
          if (_scanResult.status == ArScanStatus.locked && _scanResult.peer != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: _LockedPeerCard(
                  peer: _scanResult.peer!,
                  onConnect: () => _connectToPeer(_scanResult.peer!),
                  onCancel: () => setState(() =>
                      _scanResult = const ArScanResult(status: ArScanStatus.scanning)),
                ),
              ),
            ),

          // Show my QR button
          Positioned(
            bottom: _scanResult.status == ArScanStatus.locked ? 200 : 40,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: 'show_qr',
              backgroundColor: Colors.white24,
              onPressed: () => _showMyQr(context),
              child: const Icon(Icons.qr_code, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _connectToPeer(DiscoveredPeer peer) {
    _ar.confirmConnection(peer);
    ref.read(syncStateProvider.notifier).syncWithPeer(peer);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 8),
          Text('Connecting to ${peer.name}…'),
        ]),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showMyQr(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MyQrSheet(),
    );
  }
}

// ─── AR Overlay ───────────────────────────────────────────────────────────────

class _ArOverlay extends StatelessWidget {
  final AnimationController scanCtrl;
  final ArScanResult result;
  const _ArOverlay({required this.scanCtrl, required this.result});

  @override
  Widget build(BuildContext context) {
    final isLocked = result.status == ArScanStatus.locked;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dark vignette
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.8,
                colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
              ),
            ),
          ),

          // Scanning reticle
          Center(
            child: AnimatedBuilder(
              animation: scanCtrl,
              builder: (_, __) => _ScanReticle(
                progress: scanCtrl.value,
                isLocked: isLocked,
                color: isLocked ? AppColors.success : AppColors.neon,
              ),
            ),
          ),

          // Scan line
          if (!isLocked)
            Center(
              child: AnimatedBuilder(
                animation: scanCtrl,
                builder: (_, __) {
                  final y = (scanCtrl.value * 220) - 110;
                  return Transform.translate(
                    offset: Offset(0, y),
                    child: Container(
                      width: 220,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          AppColors.neon.withOpacity(0.9),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Status text
          Positioned(
            top: MediaQuery.of(context).size.height * 0.65,
            left: 0,
            right: 0,
            child: Text(
              switch (result.status) {
                ArScanStatus.scanning  => 'Point at peer\'s QR code',
                ArScanStatus.locked    => '🎯 Target locked!',
                ArScanStatus.connected => '✅ Connected!',
                ArScanStatus.error     => '⚠️ Scan failed',
                _                     => '',
              },
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isLocked ? AppColors.success : Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ).animate(key: ValueKey(result.status)).fadeIn(),
          ),
        ],
      ),
    );
  }
}

// ─── Scan reticle ─────────────────────────────────────────────────────────────

class _ScanReticle extends StatelessWidget {
  final double progress;
  final bool isLocked;
  final Color color;
  const _ScanReticle({required this.progress, required this.isLocked, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(220, 220),
      painter: _ReticlePainter(progress: progress, isLocked: isLocked, color: color),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final double progress;
  final bool isLocked;
  final Color color;
  _ReticlePainter({required this.progress, required this.isLocked, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(isLocked ? 1 : 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 30.0;
    const r = Radius.circular(4);
    final w = size.width, h = size.height;

    // Corners
    final corners = [
      [Offset(0, cornerLen), Offset(0, 0), Offset(cornerLen, 0)],
      [Offset(w - cornerLen, 0), Offset(w, 0), Offset(w, cornerLen)],
      [Offset(w, h - cornerLen), Offset(w, h), Offset(w - cornerLen, h)],
      [Offset(0, h - cornerLen), Offset(0, h), Offset(cornerLen, h)],
    ];

    for (final c in corners) {
      final path = Path()..moveTo(c[0].dx, c[0].dy)..lineTo(c[1].dx, c[1].dy)..lineTo(c[2].dx, c[2].dy);
      canvas.drawPath(path, paint);
    }

    // Pulse ring when locked
    if (isLocked) {
      final pulsePaint = Paint()
        ..color = color.withOpacity(0.3 * (1 - progress))
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawRect(
        Rect.fromLTWH(-progress * 20, -progress * 20,
            w + progress * 40, h + progress * 40),
        pulsePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ReticlePainter old) =>
      old.progress != progress || old.isLocked != isLocked;
}

// ─── Top HUD ──────────────────────────────────────────────────────────────────

class _TopHud extends StatelessWidget {
  final VoidCallback onClose;
  final ArScanStatus status;
  const _TopHud({required this.onClose, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: onClose,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: AppColors.neon, shape: BoxShape.circle),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scaleXY(begin: 1, end: 1.5, duration: 600.ms)
                    .then()
                    .scaleXY(begin: 1.5, end: 1, duration: 600.ms),
                const SizedBox(width: 6),
                const Text('AR Targeting', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ─── Locked peer card ─────────────────────────────────────────────────────────

class _LockedPeerCard extends StatelessWidget {
  final DiscoveredPeer peer;
  final VoidCallback onConnect, onCancel;
  const _LockedPeerCard({required this.peer, required this.onConnect, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.2), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: peer.avatarColor,
                child: Text(peer.initials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(peer.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('${peer.host}:${peer.port}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
              ),
              const E2EEBadge(state: E2EEVerificationState.pending),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white54, side: const BorderSide(color: Colors.white24)),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onConnect,
                  icon: const Icon(Icons.wifi_tethering_rounded, size: 16),
                  label: Text('Connect to ${peer.name}'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOut).fadeIn();
  }
}

// ─── My QR sheet ──────────────────────────────────────────────────────────────

class _MyQrSheet extends ConsumerWidget {
  const _MyQrSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Your QR Code',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Let peers scan this to connect',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          // QR placeholder — in production use ArPeerTargeting.generateMyQrString()
          Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.qr_code_2, size: 120, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
