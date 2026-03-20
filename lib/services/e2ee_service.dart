// lib/services/e2ee_service.dart
//
// End-to-end encryption using:
//   • X25519 Diffie-Hellman for key exchange
//   • HKDF-SHA256 for key derivation
//   • AES-256-GCM for symmetric encryption
//   • Base64url for wire encoding
//
// Usage:
//   final myKeyPair = await E2EEService.generateKeyPair();
//   final shared   = await E2EEService.deriveSharedKey(myKeyPair.privateKey, peerPublicKeyB64);
//   final ct       = await E2EEService.encryptNote(noteJson, shared);
//   final plain    = await E2EEService.decryptNote(ct, shared);

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─── Key storage keys ─────────────────────────────────────────────────────────
const _kPrivKey = 'e2ee_x25519_priv_v1';
const _kPubKey  = 'e2ee_x25519_pub_v1';

/// Holds an X25519 key pair as base64url strings
class E2EEKeyPair {
  final String publicKeyBase64;
  final String privateKeyBase64;
  const E2EEKeyPair({required this.publicKeyBase64, required this.privateKeyBase64});
}

/// Wire format for an encrypted note
class EncryptedPayload {
  final String ciphertext;   // base64url AES-GCM ciphertext + tag
  final String nonce;        // base64url 12-byte GCM nonce
  final String senderPubKey; // base64url X25519 ephemeral or long-term pub

  const EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
    required this.senderPubKey,
  });

  Map<String, dynamic> toJson() => {
    'ciphertext': ciphertext,
    'nonce': nonce,
    'senderPubKey': senderPubKey,
  };

  factory EncryptedPayload.fromJson(Map<String, dynamic> j) => EncryptedPayload(
    ciphertext: j['ciphertext'] as String,
    nonce: j['nonce'] as String,
    senderPubKey: j['senderPubKey'] as String,
  );
}

// ─── E2EEService ──────────────────────────────────────────────────────────────

class E2EEService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static final _x25519    = X25519();
  static final _aesGcm    = AesGcm.with256bits();
  static final _hkdf      = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  // ─── Key management ────────────────────────────────────────────────────────

  /// Load or generate this device's long-term X25519 key pair.
  /// Keys are persisted in the platform secure enclave.
  static Future<E2EEKeyPair> getOrCreateKeyPair() async {
    final existingPriv = await _storage.read(key: _kPrivKey);
    final existingPub  = await _storage.read(key: _kPubKey);

    if (existingPriv != null && existingPub != null) {
      return E2EEKeyPair(
        publicKeyBase64: existingPub,
        privateKeyBase64: existingPriv,
      );
    }

    return generateKeyPair();
  }

  /// Generate and persist a new X25519 key pair.
  static Future<E2EEKeyPair> generateKeyPair() async {
    final keyPair     = await _x25519.newKeyPair();
    final pubKey      = await keyPair.extractPublicKey();
    final privBytes   = await keyPair.extractPrivateKeyBytes();

    final pubB64  = _toBase64(Uint8List.fromList(pubKey.bytes));
    final privB64 = _toBase64(Uint8List.fromList(privBytes));

    await _storage.write(key: _kPrivKey, value: privB64);
    await _storage.write(key: _kPubKey,  value: pubB64);

    debugPrint('[E2EE] New X25519 key pair generated. pub=${pubB64.substring(0, 12)}…');
    return E2EEKeyPair(publicKeyBase64: pubB64, privateKeyBase64: privB64);
  }

  /// Return the cached public key (call [getOrCreateKeyPair] first).
  static Future<String> getPublicKey() async {
    final kp = await getOrCreateKeyPair();
    return kp.publicKeyBase64;
  }

  // ─── Key exchange ──────────────────────────────────────────────────────────

  /// Perform X25519 DH and derive a 256-bit shared symmetric key via HKDF.
  ///
  /// Both peers must call this with each other's public keys to arrive at
  /// the same shared secret — no third party is ever involved.
  static Future<SecretKey> deriveSharedKey(
    String myPrivateKeyBase64,
    String peerPublicKeyBase64, {
    String info = 'lan-note-sync-v1',
  }) async {
    final privBytes = _fromBase64(myPrivateKeyBase64);
    final pubBytes  = _fromBase64(peerPublicKeyBase64);

    // Reconstruct key objects
    final myPrivKey  = await _x25519.newKeyPairFromSeed(privBytes);
    final peerPubKey = SimplePublicKey(pubBytes, type: KeyPairType.x25519);

    // X25519 DH
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: myPrivKey,
      remotePublicKey: peerPubKey,
    );

    // HKDF-SHA256 to derive a 256-bit key
    final derived = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: Uint8List(32), // salt = zeros; safe for ephemeral exchange
      info: Uint8List.fromList(utf8.encode(info)),
    );

    debugPrint('[E2EE] Shared key derived for peer=${peerPublicKeyBase64.substring(0, 12)}…');
    return derived;
  }

  // ─── Note encryption ───────────────────────────────────────────────────────

  /// Encrypt a note map using AES-256-GCM with the given shared key.
  /// Returns an [EncryptedPayload] ready for transmission.
  static Future<EncryptedPayload> encryptNote(
    Map<String, dynamic> note,
    SecretKey sharedKey, {
    required String senderPublicKey,
  }) async {
    final plaintext = utf8.encode(jsonEncode(note));
    final nonce     = _randomNonce();

    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: sharedKey,
      nonce: nonce,
    );

    // Concatenate ciphertext + 16-byte GCM tag
    final combined = Uint8List(secretBox.cipherText.length + secretBox.mac.bytes.length)
      ..setAll(0, secretBox.cipherText)
      ..setAll(secretBox.cipherText.length, secretBox.mac.bytes);

    return EncryptedPayload(
      ciphertext: _toBase64(combined),
      nonce: _toBase64(Uint8List.fromList(nonce)),
      senderPubKey: senderPublicKey,
    );
  }

  /// Decrypt an [EncryptedPayload] using the shared key.
  /// Returns the original note map, or null if authentication fails.
  static Future<Map<String, dynamic>?> decryptNote(
    EncryptedPayload payload,
    SecretKey sharedKey,
  ) async {
    try {
      final combined  = _fromBase64(payload.ciphertext);
      final nonce     = _fromBase64(payload.nonce);
      final tagLength = 16;

      final ciphertext = combined.sublist(0, combined.length - tagLength);
      final mac        = combined.sublist(combined.length - tagLength);

      final secretBox = SecretBox(ciphertext, nonce: nonce, mac: Mac(mac));
      final plaintext = await _aesGcm.decrypt(secretBox, secretKey: sharedKey);

      return jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    } on SecretBoxAuthenticationError {
      debugPrint('[E2EE] ⚠️  Authentication FAILED — payload was tampered!');
      return null;
    } catch (e) {
      debugPrint('[E2EE] Decrypt error: $e');
      return null;
    }
  }

  // ─── Bulk encrypt/decrypt ──────────────────────────────────────────────────

  /// Encrypt multiple notes for a single peer in one call.
  static Future<List<EncryptedPayload>> encryptNotes(
    List<Map<String, dynamic>> notes,
    SecretKey sharedKey, {
    required String senderPublicKey,
  }) async {
    return Future.wait(
      notes.map((n) => encryptNote(n, sharedKey, senderPublicKey: senderPublicKey)),
    );
  }

  /// Decrypt multiple payloads; failed items are silently dropped.
  static Future<List<Map<String, dynamic>>> decryptNotes(
    List<EncryptedPayload> payloads,
    SecretKey sharedKey,
  ) async {
    final results = await Future.wait(
      payloads.map((p) => decryptNote(p, sharedKey)),
    );
    return results.whereType<Map<String, dynamic>>().toList();
  }

  // ─── Fingerprint ───────────────────────────────────────────────────────────

  /// Short human-readable fingerprint of a public key for UI display.
  /// e.g. "A3:F7:2B:91"
  static String fingerprint(String publicKeyBase64) {
    final bytes = _fromBase64(publicKeyBase64);
    return bytes
        .take(4)
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static String _toBase64(Uint8List bytes) => base64Url.encode(bytes);
  static Uint8List _fromBase64(String b64) => Uint8List.fromList(base64Url.decode(b64));

  static List<int> _randomNonce() {
    final rand = Random.secure();
    return List.generate(12, (_) => rand.nextInt(256));
  }
}
