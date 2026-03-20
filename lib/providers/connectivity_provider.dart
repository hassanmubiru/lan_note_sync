// lib/providers/connectivity_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/network/connectivity_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final svc = ConnectivityService();
  ref.onDispose(() => svc.dispose());
  return svc;
});

final connectivityProvider = StreamProvider<NetworkStatus>((ref) async* {
  final svc = ref.watch(connectivityServiceProvider);
  await svc.start();
  yield svc.status;
  yield* svc.statusStream;
});

final networkModeProvider = Provider<NetworkMode>((ref) {
  return ref.watch(connectivityProvider).maybeWhen(
    data: (s) => s.mode,
    orElse: () => NetworkMode.unknown,
  );
});

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).maybeWhen(
    data: (s) => s.isOnline,
    orElse: () => false,
  );
});
