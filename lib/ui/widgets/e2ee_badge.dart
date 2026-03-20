// lib/ui/widgets/e2ee_badge.dart
//
// E2EE Badge — visual trust indicators for the UI.
//
// Components:
//   E2EEBadge           — inline status chip (Verified / Unverified / Pending)
//   E2EEStatusBanner    — full-width banner for the editor/peer screen
//   E2EEFingerprintCard — shows key fingerprints for manual verification
//   KeyExchangeSheet    — bottom sheet shown during NFC/QR handshake

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants.dart';
import '../../services/e2ee_service.dart';

// ─── Verification state ───────────────────────────────────────────────────────

enum E2EEVerificationState {
  verified,       // Key exchange complete, shared secret derived
  pending,        // Handshake in progress
  unverified,     // Connected but no E2EE (fallback mode)
  failed,         // Authentication error
}

// ─── E2EE chip badge ──────────────────────────────────────────────────────────

class E2EEBadge extends StatelessWidget {
  final E2EEVerificationState state;
  final bool compact;

  const E2EEBadge({
    super.key,
    required this.state,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (state) {
      E2EEVerificationState.verified   => (Icons.verified_user, 'E2EE Verified', AppColors.success),
      E2EEVerificationState.pending    => (Icons.lock_clock_outlined, 'Handshaking…', AppColors.warning),
      E2EEVerificationState.unverified => (Icons.lock_open_outlined, 'No E2EE', Colors.grey),
      E2EEVerificationState.failed     => (Icons.gpp_bad_outlined, 'Auth Failed', AppColors.error),
    };

    return AnimatedContainer(
      duration: AppConstants.animationFast,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          state == E2EEVerificationState.pending
              ? SizedBox(
                  width: 10, height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: color,
                  ),
                )
              : Icon(icon, size: compact ? 10 : 12, color: color),
          if (!compact) ...[
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    )
        .animate(key: ValueKey(state))
        .fadeIn(duration: AppConstants.animationFast);
  }
}

// ─── E2EE status banner ───────────────────────────────────────────────────────

/// Full-width banner shown at the top of the note editor.
class E2EEStatusBanner extends StatelessWidget {
  final E2EEVerificationState state;
  final String? peerName;
  final String? fingerprint;
  final VoidCallback? onTapDetails;

  const E2EEStatusBanner({
    super.key,
    required this.state,
    this.peerName,
    this.fingerprint,
    this.onTapDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bgColor, icon, message) = switch (state) {
      E2EEVerificationState.verified => (
        AppColors.success.withOpacity(0.08),
        Icons.verified_user,
        'E2EE secured${peerName != null ? ' with $peerName' : ''}'
            '${fingerprint != null ? ' · 🔑 $fingerprint' : ''}',
      ),
      E2EEVerificationState.pending => (
        AppColors.warning.withOpacity(0.08),
        Icons.lock_clock_outlined,
        'Establishing E2EE channel…',
      ),
      E2EEVerificationState.unverified => (
        Colors.grey.withOpacity(0.06),
        Icons.lock_open_outlined,
        'This note is not encrypted end-to-end',
      ),
      E2EEVerificationState.failed => (
        AppColors.error.withOpacity(0.08),
        Icons.gpp_bad_outlined,
        '⚠️ E2EE authentication failed — do not share sensitive data',
      ),
    };

    final borderColor = switch (state) {
      E2EEVerificationState.verified   => AppColors.success.withOpacity(0.25),
      E2EEVerificationState.pending    => AppColors.warning.withOpacity(0.25),
      E2EEVerificationState.unverified => Colors.grey.withOpacity(0.15),
      E2EEVerificationState.failed     => AppColors.error.withOpacity(0.25),
    };

    final textColor = switch (state) {
      E2EEVerificationState.verified   => AppColors.success,
      E2EEVerificationState.pending    => AppColors.warning,
      E2EEVerificationState.unverified => Colors.grey,
      E2EEVerificationState.failed     => AppColors.error,
    };

    return GestureDetector(
      onTap: onTapDetails,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(
          children: [
            state == E2EEVerificationState.pending
                ? SizedBox(
                    width: 13, height: 13,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: textColor),
                  )
                : Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500),
              ),
            ),
            if (onTapDetails != null)
              Icon(Icons.info_outline, size: 13, color: textColor.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}

// ─── Fingerprint card ─────────────────────────────────────────────────────────

/// Shows both parties' key fingerprints for out-of-band verification
/// (like Signal's safety numbers).
class E2EEFingerprintCard extends StatefulWidget {
  final String myPublicKeyBase64;
  final String? peerPublicKeyBase64;
  final String peerName;

  const E2EEFingerprintCard({
    super.key,
    required this.myPublicKeyBase64,
    required this.peerPublicKeyBase64,
    required this.peerName,
  });

  @override
  State<E2EEFingerprintCard> createState() => _E2EEFingerprintCardState();
}

class _E2EEFingerprintCardState extends State<E2EEFingerprintCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myFingerprint   = E2EEService.fingerprint(widget.myPublicKeyBase64);
    final peerFingerprint = widget.peerPublicKeyBase64 != null
        ? E2EEService.fingerprint(widget.peerPublicKeyBase64!)
        : '—';

    return Card(
      margin: const EdgeInsets.all(0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fingerprint, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text('Security Keys',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _revealed = !_revealed),
                  style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: Text(_revealed ? 'Hide' : 'Show full key',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _FingerprintRow(
              label: 'You',
              fingerprint: myFingerprint,
              fullKey: _revealed ? widget.myPublicKeyBase64 : null,
              color: AppColors.primary,
            ),

            const SizedBox(height: 8),

            _FingerprintRow(
              label: widget.peerName,
              fingerprint: peerFingerprint,
              fullKey: _revealed && widget.peerPublicKeyBase64 != null
                  ? widget.peerPublicKeyBase64!
                  : null,
              color: AppColors.secondary,
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            Text(
              'Compare fingerprints with ${widget.peerName} in person or via a separate channel to verify authenticity.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.55),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FingerprintRow extends StatelessWidget {
  final String label, fingerprint;
  final String? fullKey;
  final Color color;

  const _FingerprintRow({
    required this.label,
    required this.fingerprint,
    required this.color,
    this.fullKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fingerprint,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              if (fullKey != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SelectableText(
                    fullKey!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace', fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 14),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: fullKey ?? fingerprint));
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Copy',
          color: color.withOpacity(0.6),
        ),
      ],
    );
  }
}

// ─── Key exchange sheet ────────────────────────────────────────────────────────

/// Bottom sheet shown during NFC/QR-based E2EE handshake.
class KeyExchangeSheet extends StatelessWidget {
  final String peerName;
  final E2EEVerificationState state;
  final String? myFingerprint;
  final VoidCallback? onVerify;
  final VoidCallback? onCancel;

  const KeyExchangeSheet({
    super.key,
    required this.peerName,
    required this.state,
    this.myFingerprint,
    this.onVerify,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),

          // Status icon
          AnimatedSwitcher(
            duration: AppConstants.animationMedium,
            child: switch (state) {
              E2EEVerificationState.verified => const Text('🔐', style: TextStyle(fontSize: 48)),
              E2EEVerificationState.pending  => const SizedBox(
                  width: 48, height: 48,
                  child: CircularProgressIndicator(color: AppColors.warning, strokeWidth: 3),
                ),
              E2EEVerificationState.failed   => const Text('⚠️', style: TextStyle(fontSize: 48)),
              _                             => const Text('🔓', style: TextStyle(fontSize: 48)),
            },
          ),

          const SizedBox(height: 16),

          Text(
            switch (state) {
              E2EEVerificationState.verified   => 'E2EE Ready',
              E2EEVerificationState.pending    => 'Exchanging Keys…',
              E2EEVerificationState.failed     => 'Handshake Failed',
              E2EEVerificationState.unverified => 'No Encryption',
            },
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 8),

          Text(
            switch (state) {
              E2EEVerificationState.verified =>
                'Secure channel established with $peerName.\nAll notes are now end-to-end encrypted.',
              E2EEVerificationState.pending =>
                'Performing X25519 Diffie-Hellman key exchange\nwith $peerName…',
              E2EEVerificationState.failed =>
                'Could not authenticate $peerName.\nDo NOT share sensitive notes.',
              E2EEVerificationState.unverified =>
                'Connect to $peerName to enable E2EE.',
            },
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5, color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),

          if (myFingerprint != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fingerprint, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    myFingerprint!,
                    style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 14,
                      color: AppColors.primary, fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          Row(children: [
            if (onCancel != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
            if (onCancel != null) const SizedBox(width: 12),
            if (onVerify != null && state == E2EEVerificationState.verified)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onVerify,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Start Sharing'),
                ),
              ),
          ]),
        ],
      ),
    );
  }
}
