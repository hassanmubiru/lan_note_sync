// lib/services/crypto/crypto_service.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart';

class CryptoService {
  static late AsymmetricKeyPair<PublicKey, PrivateKey> _keyPair;
  static late String _publicKeyPem;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _keyPair = _generateRSAKeyPair();
    _publicKeyPem = _publicKeyToBase64(_keyPair.publicKey as RSAPublicKey);
    _initialized = true;
  }

  // ─── Key Management ───────────────────────────────────────────────────────

  static String get publicKeyBase64 => _publicKeyPem;

  static AsymmetricKeyPair<PublicKey, PrivateKey> _generateRSAKeyPair() {
    final keyGen = RSAKeyGenerator();
    final secureRandom = _buildSecureRandom();
    keyGen.init(ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
      secureRandom,
    ));
    return keyGen.generateKeyPair();
  }

  static SecureRandom _buildSecureRandom() {
    final random = Random.secure();
    final seed = Uint8List(32)..fillRange(0, 32, 0);
    for (var i = 0; i < seed.length; i++) {
      seed[i] = random.nextInt(256);
    }
    return SecureRandom('Fortuna')..seed(KeyParameter(seed));
  }

  static String _publicKeyToBase64(RSAPublicKey key) {
    final encoded = ASN1Sequence(elements: [
      ASN1Integer(key.modulus!),
      ASN1Integer(key.exponent!),
    ]);
    return base64Encode(encoded.encode());
  }

  static RSAPublicKey _publicKeyFromBase64(String base64Str) {
    final bytes = base64Decode(base64Str);
    final asn1 = ASN1Parser(bytes).nextObject() as ASN1Sequence;
    final modulus = (asn1.elements![0] as ASN1Integer).integer!;
    final exponent = (asn1.elements![1] as ASN1Integer).integer!;
    return RSAPublicKey(modulus, exponent);
  }

  // ─── Symmetric AES Encryption ─────────────────────────────────────────────

  /// Generate a random AES-256 session key
  static Uint8List generateSessionKey() {
    final rand = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rand.nextInt(256)));
  }

  /// Encrypt data using AES-256-GCM
  static Uint8List encryptAES(Uint8List data, Uint8List key) {
    final iv = Uint8List(16)
      ..setAll(0, List.generate(16, (_) => Random.secure().nextInt(256)));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
      );

    final encrypted = cipher.process(data);
    // Prepend IV to encrypted data
    return Uint8List(iv.length + encrypted.length)
      ..setAll(0, iv)
      ..setAll(iv.length, encrypted);
  }

  /// Decrypt data using AES-256-GCM
  static Uint8List decryptAES(Uint8List data, Uint8List key) {
    final iv = data.sublist(0, 16);
    final encrypted = data.sublist(16);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
      );

    return cipher.process(encrypted);
  }

  // ─── RSA Encrypt Session Key ──────────────────────────────────────────────

  /// Encrypt a session key with a peer's public key
  static String encryptSessionKey(Uint8List sessionKey, String peerPublicKeyBase64) {
    final publicKey = _publicKeyFromBase64(peerPublicKeyBase64);
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final encrypted = cipher.process(sessionKey);
    return base64Encode(encrypted);
  }

  /// Decrypt an encrypted session key with our private key
  static Uint8List decryptSessionKey(String encryptedBase64) {
    final encrypted = base64Decode(encryptedBase64);
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(_keyPair.privateKey as RSAPrivateKey));

    return cipher.process(encrypted);
  }

  // ─── Message Signing ──────────────────────────────────────────────────────

  static String signMessage(String message) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(_keyPair.privateKey as RSAPrivateKey));

    final bytes = Uint8List.fromList(utf8.encode(message));
    return base64Encode(signer.generateSignature(bytes).bytes);
  }

  static bool verifySignature(String message, String signatureBase64, String publicKeyBase64) {
    try {
      final publicKey = _publicKeyFromBase64(publicKeyBase64);
      final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
        ..init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

      final bytes = Uint8List.fromList(utf8.encode(message));
      final sig = RSASignature(base64Decode(signatureBase64));
      return signer.verifySignature(bytes, sig);
    } catch (_) {
      return false;
    }
  }

  // ─── Hash ─────────────────────────────────────────────────────────────────

  static String sha256Hash(String input) {
    final digest = SHA256Digest();
    final bytes = Uint8List.fromList(utf8.encode(input));
    final hash = digest.process(bytes);
    return hex.encode(hash);
  }

  // ─── Encrypt/Decrypt Notes JSON ───────────────────────────────────────────

  /// Encrypt notes JSON for transmission to a peer
  static Map<String, String> encryptNotesForPeer(
    String notesJson,
    String peerPublicKeyBase64,
  ) {
    final sessionKey = generateSessionKey();
    final dataBytes = Uint8List.fromList(utf8.encode(notesJson));
    final encryptedData = encryptAES(dataBytes, sessionKey);
    final encryptedKey = encryptSessionKey(sessionKey, peerPublicKeyBase64);

    return {
      'encryptedData': base64Encode(encryptedData),
      'encryptedKey': encryptedKey,
    };
  }

  /// Decrypt notes JSON received from a peer
  static String decryptNotesFromPeer(
    String encryptedDataBase64,
    String encryptedKeyBase64,
  ) {
    final sessionKey = decryptSessionKey(encryptedKeyBase64);
    final encryptedData = base64Decode(encryptedDataBase64);
    final decryptedBytes = decryptAES(encryptedData, sessionKey);
    return utf8.decode(decryptedBytes);
  }
}
