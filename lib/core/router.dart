// lib/core/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/peer.dart';
import '../models/note.dart';
import '../services/storage/hive_service.dart';
import '../ui/screens/home/home_screen.dart';
import '../ui/screens/onboarding/onboarding_screen.dart';
import '../ui/screens/editor/note_editor_screen.dart';
import '../ui/screens/peer/peer_detail_screen.dart';
import '../ui/screens/conflict/conflict_screen.dart';
import '../ui/screens/settings/settings_screen.dart';
import '../ui/screens/voice/voice_screen.dart';
import '../ui/screens/ar_whiteboard/ar_whiteboard_screen.dart';
import '../ui/screens/room/room_screen.dart';
import '../ui/screens/monetization/monetization_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final done = HiveService.getSetting<bool>('onboarding_done') ?? false;
    if (!done && state.matchedLocation != '/onboarding') return '/onboarding';
    return null;
  },
  routes: [
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(
      path: '/note/new',
      builder: (_, state) => NoteEditorScreen(
        initialFolder: state.uri.queryParameters['folder'],
      ),
    ),
    GoRoute(
      path: '/note/:id',
      builder: (_, state) => NoteEditorScreen(
        noteId: state.pathParameters['id'],
        note: state.extra as Note?,
      ),
    ),
    GoRoute(
      path: '/peer/:id',
      builder: (_, state) => PeerDetailScreen(
        peerId: state.pathParameters['id']!,
        peer: state.extra as DiscoveredPeer?,
      ),
    ),
    GoRoute(
      path: '/conflict',
      builder: (_, state) => ConflictScreen(args: state.extra as ConflictScreenArgs),
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(
      path: '/voice',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return VoiceScreen(onTranscriptDone: extra?['onDone'] as void Function(String)?);
      },
    ),
    GoRoute(path: '/ar', builder: (_, __) => const ArWhiteboardScreen()),
    GoRoute(path: '/rooms', builder: (_, __) => const RoomScreen()),
    GoRoute(path: '/monetization', builder: (_, __) => const MonetizationScreen()),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text('Not found: ${state.uri}'),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: () => context.go('/'), child: const Text('Home')),
      ],
    )),
  ),
);
