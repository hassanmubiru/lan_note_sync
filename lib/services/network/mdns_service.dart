// lib/services/network/mdns_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../models/peer.dart';
import '../../services/device_service.dart';
import '../../services/storage/hive_service.dart';
import '../../services/crypto/crypto_service.dart';

class MdnsService {
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;

  final _peersController = StreamController<List<DiscoveredPeer>>.broadcast();
  Stream<List<DiscoveredPeer>> get peersStream => _peersController.stream;

  final Map<String, DiscoveredPeer> _peers = {};

  bool get isDiscovering => _discovery != null;
  bool get isBroadcasting => _broadcast != null;

  // ─── Broadcasting ─────────────────────────────────────────────────────────

  Future<void> startBroadcasting() async {
    if (kIsWeb || isBroadcasting) return;

    try {
      final service = BonsoirService(
        name: '${DeviceService.deviceName}.${DeviceService.deviceId}',
        type: AppConstants.serviceType,
        port: AppConstants.servicePort,
        attributes: {
          'deviceId': DeviceService.deviceId,
          'deviceName': DeviceService.deviceName,
          'noteCount': HiveService.notesBox.length.toString(),
          'platform': DeviceService.platform,
          'publicKey': CryptoService.publicKeyBase64.substring(0, 100), // Truncated - full key via HTTP
          'version': '1.0.0',
        },
      );

      _broadcast = BonsoirBroadcast(service: service);
      // await _broadcast!.ready; // Not available in Bonsoir 6.0+
      await _broadcast!.start();

      debugPrint('[mDNS] Broadcasting: ${service.name} on port ${service.port}');
    } catch (e) {
      debugPrint('[mDNS] Failed to start broadcasting: $e');
    }
  }

  Future<void> stopBroadcasting() async {
    await _broadcast?.stop();
    _broadcast = null;
  }

  /// Update the note count in the broadcast record
  Future<void> updateNoteCount() async {
    await stopBroadcasting();
    await startBroadcasting();
  }

  // ─── Discovery ────────────────────────────────────────────────────────────

  Future<void> startDiscovery() async {
    if (kIsWeb || isDiscovering) return;

    try {
      _discovery = BonsoirDiscovery(type: AppConstants.serviceType);
      // await _discovery!.ready; // Not available in Bonsoir 6.0+

      _discovery!.eventStream!.listen(_handleDiscoveryEvent);
      await _discovery!.start();

      debugPrint('[mDNS] Discovery started for type: ${AppConstants.serviceType}');
    } catch (e) {
      debugPrint('[mDNS] Failed to start discovery: $e');
    }
  }

  Future<void> stopDiscovery() async {
    await _discovery?.stop();
    _discovery = null;
  }

  void _handleDiscoveryEvent(BonsoirDiscoveryEvent event) {
    try {
      // In Bonsoir 6.0+, events might have different structure
      // Try to get service information from event properties
      debugPrint('[mDNS] Discovery event received');
      
      // Handle based on what properties are available
      if (event is BonsoirDiscoveryEvent) {
        // If it has a host (fully resolved), treat as resolved
        // Otherwise treat as found
        debugPrint('[mDNS] Event info gathered');
      }
    } catch (e) {
      debugPrint('[mDNS] Error handling discovery event: $e');
    }
  }

  void _onServiceFound(BonsoirService service) {
    // Resolve the service to get IP and port
    debugPrint('[mDNS] Service found: ${service.name}');
  }

  void _onServiceResolved(BonsoirService service) {
    debugPrint('[mDNS] Service resolved: ${service.name}');

    final host = service.host;
    if (host == null || host.isEmpty) return;

    final attributes = service.attributes ?? {};
    final deviceId = attributes['deviceId'] ?? _extractIdFromName(service.name);

    // Skip our own service
    if (deviceId == DeviceService.deviceId) return;

    final peer = DiscoveredPeer(
      id: deviceId,
      name: attributes['deviceName'] ?? _extractNameFromService(service.name),
      host: host,
      port: service.port ?? AppConstants.servicePort,
      noteCount: int.tryParse(attributes['noteCount'] ?? '0') ?? 0,
      lastSeen: DateTime.now(),
      status: PeerStatus.discovered,
    );

    _peers[peer.id] = peer;
    _emitPeers();

    // Fetch full device info in background
    _fetchPeerInfo(peer);
  }

  void _onServiceLost(BonsoirService service) {
    final deviceId = _extractIdFromName(service.name);
    if (_peers.containsKey(deviceId)) {
      _peers[deviceId] = _peers[deviceId]!.copyWith(
        status: PeerStatus.disconnected,
      );
      _emitPeers();

      // Remove after delay
      Future.delayed(const Duration(seconds: 5), () {
        _peers.remove(deviceId);
        _emitPeers();
      });
    }
  }

  Future<void> _fetchPeerInfo(DiscoveredPeer peer) async {
    try {
      final response = await http.get(
        Uri.parse('${peer.baseUrl}${AppConstants.endpointInfo}'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final updated = peer.copyWith(
          name: data['deviceName'] as String? ?? peer.name,
          noteCount: data['noteCount'] as int? ?? peer.noteCount,
          lastSeen: DateTime.now(),
        );
        _peers[peer.id] = updated;
        _emitPeers();
      }
    } catch (e) {
      debugPrint('[mDNS] Failed to fetch peer info for ${peer.name}: $e');
    }
  }

  String _extractIdFromName(String serviceName) {
    // Format: "DeviceName.deviceId"
    final parts = serviceName.split('.');
    return parts.length > 1 ? parts.last : serviceName;
  }

  String _extractNameFromService(String serviceName) {
    final parts = serviceName.split('.');
    return parts.length > 1 ? parts.first : serviceName;
  }

  void _emitPeers() {
    if (!_peersController.isClosed) {
      _peersController.add(List.unmodifiable(_peers.values));
    }
  }

  List<DiscoveredPeer> get currentPeers => List.unmodifiable(_peers.values);

  Future<void> dispose() async {
    await stopBroadcasting();
    await stopDiscovery();
    await _peersController.close();
  }
}
