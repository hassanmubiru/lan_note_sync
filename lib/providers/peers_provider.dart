// lib/providers/peers_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/note.dart';
import '../models/peer.dart';
import '../services/network/mdns_service.dart';
import '../services/network/webrtc_service.dart';
import '../services/network/http_server_service.dart';
import '../services/sync/sync_service.dart';
import '../services/storage/hive_service.dart';
import 'notes_provider.dart';

final httpServerProvider = Provider<HttpServerService?>((ref) {
  if (kIsWeb) return null;
  final service = HttpServerService(
    onNotesReceived: (notes, sourceId) {
      ref.read(notesProvider.notifier).mergeIncoming(notes, sourceId);
    },
  );
  ref.onDispose(() => service.stop());
  return service;
});

final mdnsServiceProvider = Provider<MdnsService?>((ref) {
  if (kIsWeb) return null;
  final service = MdnsService();
  ref.onDispose(() => service.dispose());
  return service;
});

// TODO: Re-enable WebRTC support - API updated in newer versions
// final webRtcServiceProvider = Provider<WebRTCService?>((ref) {
//   if (!kIsWeb) return null;
//   final service = WebRTCService(
//     signalingUrl: AppConstants.defaultSignalingUrl,
//   );
//   ref.onDispose(() => service.dispose());
//   return service;
// });

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    httpServer: ref.watch(httpServerProvider),
    webRtcService: null, // WebRTC disabled - ref.watch(webRtcServiceProvider),
  );
});

final networkInitProvider = FutureProvider<bool>((ref) async {
  if (!kIsWeb) {
    await ref.read(httpServerProvider)?.start();
    final mdns = ref.read(mdnsServiceProvider);
    await mdns?.startBroadcasting();
    await mdns?.startDiscovery();
  } else {
    final url = HiveService.getSetting<String>('signaling_url')
        ?? AppConstants.defaultSignalingUrl;
    await ref.read(webRtcServiceProvider)?.connect(url);
  }
  return true;
});

class PeersNotifier extends AsyncNotifier<List<DiscoveredPeer>> {
  StreamSubscription? _sub;

  @override
  Future<List<DiscoveredPeer>> build() async {
    await ref.watch(networkInitProvider.future);
    if (!kIsWeb) {
      final mdns = ref.watch(mdnsServiceProvider);
      if (mdns != null) {
        _sub = mdns.peersStream.listen((peers) {
          state = AsyncData(peers);
        });
        ref.onDispose(() => _sub?.cancel());
        return mdns.currentPeers;
      }
    }
    // WebRTC disabled for now
    return [];
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    if (!kIsWeb) {
      final mdns = ref.read(mdnsServiceProvider);
      await mdns?.stopDiscovery();
      await Future.delayed(const Duration(milliseconds: 500));
      await mdns?.startDiscovery();
      await Future.delayed(const Duration(seconds: 2));
      state = AsyncData(mdns?.currentPeers ?? []);
    } else {
      // WebRTC disabled for now
      state = const AsyncData([]);
    }
  }

  void updatePeerStatus(String peerId, PeerStatus status) {
    state.whenData((peers) {
      state = AsyncData(
        peers.map((p) => p.id == peerId ? p.copyWith(status: status) : p).toList(),
      );
    });
  }
}

final peersProvider =
    AsyncNotifierProvider<PeersNotifier, List<DiscoveredPeer>>(PeersNotifier.new);

enum SyncStatus { idle, syncing, success, conflict, error }

class SyncState {
  final SyncStatus status;
  final String? message;
  final List<Note> conflicts;
  final String? activePeerId;
  final int progress, total;

  const SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.conflicts = const [],
    this.activePeerId,
    this.progress = 0,
    this.total = 0,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    List<Note>? conflicts,
    String? activePeerId,
    int? progress,
    int? total,
  }) =>
      SyncState(
        status: status ?? this.status,
        message: message ?? this.message,
        conflicts: conflicts ?? this.conflicts,
        activePeerId: activePeerId ?? this.activePeerId,
        progress: progress ?? this.progress,
        total: total ?? this.total,
      );
}

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  SyncNotifier(this._ref) : super(const SyncState());

  Future<void> syncWithPeer(DiscoveredPeer peer) async {
    state = SyncState(status: SyncStatus.syncing, message: 'Syncing with ${peer.name}...', activePeerId: peer.id);
    _ref.read(peersProvider.notifier).updatePeerStatus(peer.id, PeerStatus.syncing);
    try {
      final result = await _ref.read(syncServiceProvider).syncBidirectional(peer);
      if (result.conflicts.isNotEmpty) {
        state = state.copyWith(status: SyncStatus.conflict, message: '${result.conflicts.length} conflict(s)', conflicts: result.conflicts);
      } else {
        state = state.copyWith(status: SyncStatus.success, message: 'Synced ${result.notesReceived + result.notesSent} notes');
        await _ref.read(notesProvider.notifier).refresh();
        Future.delayed(const Duration(seconds: 3), () { if (mounted) state = const SyncState(); });
      }
      _ref.read(peersProvider.notifier).updatePeerStatus(peer.id, PeerStatus.connected);
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, message: 'Sync failed: $e');
      _ref.read(peersProvider.notifier).updatePeerStatus(peer.id, PeerStatus.error);
    }
  }

  Future<void> shareNotesWith(DiscoveredPeer peer, List<Note> notes) async {
    state = SyncState(status: SyncStatus.syncing, message: 'Sharing ${notes.length} note(s)...', activePeerId: peer.id, total: notes.length);
    _ref.read(peersProvider.notifier).updatePeerStatus(peer.id, PeerStatus.syncing);
    try {
      final result = await _ref.read(syncServiceProvider).pushToPeer(peer, notes);
      state = state.copyWith(
        status: result.result == SyncResult.success ? SyncStatus.success : SyncStatus.error,
        message: result.result == SyncResult.success ? 'Shared ${result.notesSent} notes!' : 'Failed: ${result.error}',
        progress: result.notesSent,
      );
      _ref.read(peersProvider.notifier).updatePeerStatus(peer.id, PeerStatus.connected);
      if (result.result == SyncResult.success) {
        Future.delayed(const Duration(seconds: 3), () { if (mounted) state = const SyncState(); });
      }
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, message: 'Failed: $e');
      _ref.read(peersProvider.notifier).updatePeerStatus(peer.id, PeerStatus.error);
    }
  }

  Future<void> shareAllNotes(DiscoveredPeer peer) async {
    await shareNotesWith(peer, HiveService.getAllNotes());
  }

  void clearState() => state = const SyncState();
}

final syncStateProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) => SyncNotifier(ref));

final peerNoteMetaProvider =
    FutureProvider.family<List<Map<String, dynamic>>, DiscoveredPeer>((ref, peer) async {
  if (kIsWeb) return [];
  try {
    final res = await http
        .get(Uri.parse('${peer.baseUrl}${AppConstants.endpointNotes}'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['notes'] as List? ?? []);
  } catch (_) {
    return [];
  }
});

final signalingUrlProvider = StateProvider<String>((ref) =>
    HiveService.getSetting<String>('signaling_url') ?? AppConstants.defaultSignalingUrl);
