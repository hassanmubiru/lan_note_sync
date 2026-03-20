// lib/services/ar_peer_targeting.dart
//
// AR Peer Targeting — point camera at peer to initiate note sync.
//
// Mechanism:
//   1. Each device shows a QR code containing its {deviceId, host, port, pubKey}
//   2. Scanning peer's QR via MobileScanner connects & initiates E2EE sync
//   3. Optionally overlays an "AR beam" animation when target is locked
//
// Note: Full AR (arkit/arcore) is complex to integrate with plugin support
// varying across platforms. This implementation uses MobileScanner for reliable
// cross-platform QR-based targeting with an AR-feel overlay animation.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/peer.dart';
import '../core/constants.dart';
import '../services/device_service.dart';
import '../services/e2ee_service.dart';

// ─── Scan result ──────────────────────────────────────────────────────────────

enum ArScanStatus { idle, scanning, locked, connected, error }

class ArScanResult {
  final ArScanStatus status;
  final DiscoveredPeer? peer;
  final String? error;
  final String? rawQrData;

  const ArScanResult({
    required this.status,
    this.peer,
    this.error,
    this.rawQrData,
  });

  bool get isLocked    => status == ArScanStatus.locked;
  bool get isConnected => status == ArScanStatus.connected;
}

// ─── QR payload ───────────────────────────────────────────────────────────────

class ArQrPayload {
  final String deviceId;
  final String deviceName;
  final String host;
  final int port;
  final String publicKey;
  final String version;

  const ArQrPayload({
    required this.deviceId,
    required this.deviceName,
    required this.host,
    required this.port,
    required this.publicKey,
    this.version = '1',
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'host': host,
        'port': port,
        'publicKey': publicKey,
        'v': version,
      };

  String toQrString() => 'lannote://ar?${Uri(queryParameters: {
        'id': deviceId,
        'n': deviceName,
        'h': host,
        'p': port.toString(),
        'k': publicKey,
      }).query}';

  factory ArQrPayload.fromQrString(String qr) {
    final uri = Uri.parse(qr);
    if (uri.scheme != 'lannote' || uri.host != 'ar') {
      throw const FormatException('Not a LanNote AR QR code');
    }
    return ArQrPayload(
      deviceId: uri.queryParameters['id']!,
      deviceName: uri.queryParameters['n']!,
      host: uri.queryParameters['h']!,
      port: int.parse(uri.queryParameters['p']!),
      publicKey: uri.queryParameters['k']!,
    );
  }

  DiscoveredPeer toPeer() => DiscoveredPeer(
        id: deviceId,
        name: deviceName,
        host: host,
        port: port,
        lastSeen: DateTime.now(),
        status: PeerStatus.discovered,
        publicKey: publicKey,
      );
}

// ─── ArPeerTargeting ─────────────────────────────────────────────────────────

class ArPeerTargeting {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final _resultController = StreamController<ArScanResult>.broadcast();
  Stream<ArScanResult> get resultStream => _resultController.stream;

  bool _scanning = false;
  ArScanResult _lastResult = const ArScanResult(status: ArScanStatus.idle);

  ArScanResult get lastResult => _lastResult;
  MobileScannerController get controller => _scanner;
  bool get isScanning => _scanning;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> startScanning() async {
    if (_scanning) return;
    _scanning = true;
    _emit(const ArScanResult(status: ArScanStatus.scanning));
    debugPrint('[AR] Scanning for peer QR codes…');
  }

  Future<void> stopScanning() async {
    _scanning = false;
    _emit(const ArScanResult(status: ArScanStatus.idle));
    await _scanner.stop();
  }

  // ─── QR processing ─────────────────────────────────────────────────────────

  void onDetect(BarcodeCapture capture) {
    if (!_scanning) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      try {
        final payload = ArQrPayload.fromQrString(raw);
        final peer    = payload.toPeer();

        _emit(ArScanResult(
          status: ArScanStatus.locked,
          peer: peer,
          rawQrData: raw,
        ));

        debugPrint('[AR] Peer locked: ${peer.name} @ ${peer.host}:${peer.port}');
        return; // Process first valid QR only
      } catch (_) {
        // Not a LanNote QR — ignore
      }
    }
  }

  void confirmConnection(DiscoveredPeer peer) {
    _emit(ArScanResult(status: ArScanStatus.connected, peer: peer));
    _scanning = false;
    debugPrint('[AR] Connected to ${peer.name}');
  }

  void reportError(String error) {
    _emit(ArScanResult(status: ArScanStatus.error, error: error));
  }

  // ─── Generate this device's QR ─────────────────────────────────────────────

  static Future<String> generateMyQrString({required String myHost}) async {
    final publicKey = await E2EEService.getPublicKey();
    final payload = ArQrPayload(
      deviceId: DeviceService.deviceId,
      deviceName: DeviceService.deviceName,
      host: myHost,
      port: AppConstants.servicePort,
      publicKey: publicKey,
    );
    return payload.toQrString();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _emit(ArScanResult result) {
    _lastResult = result;
    if (!_resultController.isClosed) _resultController.add(result);
  }

  Future<void> dispose() async {
    await stopScanning();
    await _resultController.close();
    _scanner.dispose();
  }
}
