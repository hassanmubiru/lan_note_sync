// lib/providers/e2ee_provider.dart
//
// Riverpod wiring for E2EE key management and per-peer shared keys.

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/e2ee_service.dart';
import '../ui/widgets/e2ee_badge.dart';

// ─── My key pair ──────────────────────────────────────────────────────────────

final myKeyPairProvider = FutureProvider<E2EEKeyPair>((ref) async {
  return E2EEService.getOrCreateKeyPair();
});

final myPublicKeyProvider = FutureProvider<String>((ref) async {
  final kp = await ref.watch(myKeyPairProvider.future);
  return kp.publicKeyBase64;
});

final myFingerprintProvider = FutureProvider<String>((ref) async {
  final pubKey = await ref.watch(myPublicKeyProvider.future);
  return E2EEService.fingerprint(pubKey);
});

// ─── Per-peer shared key cache ────────────────────────────────────────────────

/// In-memory cache: peerId → derived shared SecretKey.
/// Cleared when a peer's public key changes.
final _sharedKeyCache   = <String, SecretKey>{};
final _peerPublicKeys   = <String, String>{};

// ─── Provider: derive shared key for a specific peer ─────────────────────────

final sharedKeyProvider =
    FutureProvider.family<SecretKey?, String>((ref, peerId) async {
  if (_sharedKeyCache.containsKey(peerId)) {
    return _sharedKeyCache[peerId];
  }

  final kp      = await ref.read(myKeyPairProvider.future);
  final peerKey = _peerPublicKeys[peerId];
  if (peerKey == null) return null;

  final sharedKey = await E2EEService.deriveSharedKey(
    kp.privateKeyBase64, peerKey,
  );
  _sharedKeyCache[peerId] = sharedKey;
  return sharedKey;
});

// ─── Provider: peer's stored public key ──────────────────────────────────────

final peerPublicKeyProvider =
    Provider.family<String?, String>((ref, peerId) {
  return _peerPublicKeys[peerId];
});

// ─── Provider: E2EE verification state per peer ───────────────────────────────

final e2eeStateProvider =
    Provider.family<E2EEVerificationState, String>((ref, peerId) {
  if (_sharedKeyCache.containsKey(peerId)) return E2EEVerificationState.verified;
  if (_peerPublicKeys.containsKey(peerId)) return E2EEVerificationState.pending;
  return E2EEVerificationState.unverified;
});

// ─── Imperative helper: register a peer's public key ─────────────────────────

/// Call this during NFC/QR/mDNS handshake once we learn a peer's X25519 pubkey.
/// Clears the cached shared key so it gets re-derived on next access.
void registerPeerPublicKey(String peerId, String publicKeyBase64) {
  _peerPublicKeys[peerId] = publicKeyBase64;
  _sharedKeyCache.remove(peerId); // invalidate old derived key
}
