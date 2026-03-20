// lib/services/nfc/nfc_service.dart
//
// NFC Tap-to-Pair: reads/writes NDEF records containing the LanNote handshake
// payload (deviceId + deviceName + publicKey + host + port).
//
// Usage:
//   final ok = await NfcService.checkAvailability();
//   if (ok) await NfcService.writeHandshake(myHost: ip, ...);
//   final peer = await NfcService.readHandshake(onError: ...);

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../../core/constants.dart';
import '../../services/device_service.dart';
import '../../services/e2ee_service.dart';

// ─── Payload ──────────────────────────────────────────────────────────────────

class NfcHandshakePayload {
  final String deviceId;
  final String deviceName;
  final String publicKey;
  final String host;
  final int port;
  final int noteCount;

  const NfcHandshakePayload({
    required this.deviceId,
    required this.deviceName,
    required this.publicKey,
    required this.host,
    required this.port,
    this.noteCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'publicKey': publicKey,
        'host': host,
        'port': port,
        'noteCount': noteCount,
      };

  factory NfcHandshakePayload.fromJson(Map<String, dynamic> j) =>
      NfcHandshakePayload(
        deviceId:   j['deviceId']   as String,
        deviceName: j['deviceName'] as String,
        publicKey:  j['publicKey']  as String,
        host:       j['host']       as String,
        port:       j['port']       as int,
        noteCount:  j['noteCount']  as int? ?? 0,
      );
}

// ─── NfcService ───────────────────────────────────────────────────────────────

class NfcService {
  static bool _available = false;

  static Future<bool> checkAvailability() async {
    if (kIsWeb) return false;
    try {
      _available = await NfcManager.instance.isAvailable();
      return _available;
    } catch (_) {
      return false;
    }
  }

  static bool get isAvailable => _available;

  // ─── Write ─────────────────────────────────────────────────────────────────

  /// Write this device's identity to an NFC tag so a peer can scan it.
  static Future<bool> writeHandshake({
    required String myHost,
    required int noteCount,
    required void Function(String error) onError,
    required void Function() onSuccess,
  }) async {
    if (!_available) {
      onError('NFC not available on this device');
      return false;
    }

    final publicKey = await E2EEService.getPublicKey();
    final payload   = NfcHandshakePayload(
      deviceId:   DeviceService.deviceId,
      deviceName: DeviceService.deviceName,
      publicKey:  publicKey,
      host:       myHost,
      port:       AppConstants.servicePort,
      noteCount:  noteCount,
    );

    final jsonBytes = utf8.encode(jsonEncode(payload.toJson()));

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              onError('Tag is not writable');
              await _stop();
              return;
            }

            final record = NdefRecord(
              typeNameFormat: NdefTypeNameFormat.mime,
              type:           Uint8List.fromList(utf8.encode(AppConstants.nfcRecordType)),
              identifier:     Uint8List(0),
              payload:        Uint8List.fromList(jsonBytes),
            );

            await ndef.write(NdefMessage([record]));
            onSuccess();
            await _stop();
          } catch (e) {
            onError(e.toString());
            await _stop();
          }
        },
      );
      return true;
    } catch (e) {
      onError(e.toString());
      return false;
    }
  }

  // ─── Read ──────────────────────────────────────────────────────────────────

  /// Scan a peer's NFC tag and return their handshake payload.
  static Future<NfcHandshakePayload?> readHandshake({
    required void Function(String error) onError,
  }) async {
    if (!_available) return null;

    final completer = Completer<NfcHandshakePayload?>();

    await NfcManager.instance.startSession(
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            onError('No NDEF data found on tag');
            await _stop();
            completer.complete(null);
            return;
          }

          final message = await ndef.read();
          for (final record in message.records) {
            if (record.typeNameFormat == NdefTypeNameFormat.mime) {
              final typeStr = utf8.decode(record.type);
              if (typeStr == AppConstants.nfcRecordType) {
                final json = jsonDecode(utf8.decode(record.payload))
                    as Map<String, dynamic>;
                await _stop();
                completer.complete(NfcHandshakePayload.fromJson(json));
                return;
              }
            }
          }

          onError('Not a LanNote NFC tag');
          await _stop();
          completer.complete(null);
        } catch (e) {
          onError(e.toString());
          await _stop();
          completer.complete(null);
        }
      },
    );

    return completer.future;
  }

  static Future<void> _stop() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }
}
