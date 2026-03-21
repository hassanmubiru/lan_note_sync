// lib/ui/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../providers/notes_provider.dart';
import '../../../providers/peers_provider.dart';
import '../../../models/peer.dart';
import '../../../providers/shake_provider.dart';
import '../../../providers/room_provider.dart';
import '../../widgets/sync_status_bar.dart';
import '../../widgets/security_badge_row.dart';
import '../../widgets/glass_card.dart';
import 'my_notes_tab.dart';
import 'nearby_tab.dart';
import '../room/room_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() => _currentTab = _tabController.index));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncState = ref.watch(syncStateProvider);
    final shakeState = ref.watch(shakeProvider);
    final peers = ref.watch(peersProvider).maybeWhen(data: (p) => p, orElse: () => <DiscoveredPeer>[]);
    final roomState = ref.watch(roomProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (ctx, innerBoxScrolled) => [
              SliverAppBar(
                floating: true,
                snap: true,
                expandedHeight: 56,
                leading: const SizedBox.shrink(),
                centerTitle: false,
                titleSpacing: 16,
                title: const Text(
                  'LanNote Sync',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(icon: const Icon(Icons.nfc_rounded), tooltip: 'NFC', onPressed: () => _showNfcSheet(context)),
                  IconButton(icon: const Icon(Icons.document_scanner_outlined), tooltip: 'AR', onPressed: () => context.push('/ar')),
                  IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    color: theme.colorScheme.surface,
                    child: TabBar(
                      controller: _tabController,
                      tabs: [
                        Tab(child: _TabLabel(Icons.note_alt_outlined, AppStrings.myNotes,
                            _countBadge(ref, notes: true))),
                        Tab(child: _TabLabel(Icons.wifi_tethering_rounded, AppStrings.nearby,
                            _countBadge(ref, notes: false))),
                        Tab(child: _TabLabel(Icons.meeting_room_outlined, AppStrings.rooms,
                            roomState.currentRoom != null ? '🟢' : null)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _HeroHeader(peerCount: peers.length, roomSsid: roomState.currentRoom?.displayName),
                ),
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SecurityBadgeRow(),
                        if (syncState.status != SyncStatus.idle) SyncStatusBar(syncState: syncState),
                if (_currentTab == 1)
                  ShakeBanner(onShake: () => _onShake(context, ref), peerCount: peers.length),
                if (_currentTab == 2 && roomState.currentRoom != null)
                  _RoomJoinedBanner(room: roomState.currentRoom!.displayName),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [MyNotesTab(), NearbyTab(), RoomScreen()],
                  ),
                ),
              ],
            ),
          ),

          // Shake peer discovery overlay
          if (shakeState.justFoundPeer != null)
            Positioned(
              bottom: 100, left: 0, right: 0,
              child: DiscoveredPeerToast(
                peerName: shakeState.justFoundPeer!.name,
                onConnect: () {
                  ref.read(shakeProvider.notifier).clearFoundPeer();
                  ref.read(syncStateProvider.notifier).syncWithPeer(shakeState.justFoundPeer!);
                },
                onDismiss: () => ref.read(shakeProvider.notifier).clearFoundPeer(),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFab(context, ref),
    );
  }

  Widget? _buildFab(BuildContext context, WidgetRef ref) {
    if (_currentTab == 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'voice_fab',
            backgroundColor: AppColors.secondary,
            onPressed: () => context.push('/voice'),
            child: const Icon(Icons.mic_rounded, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'new_fab',
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: () => context.push('/note/new'),
            icon: const Icon(Icons.add),
            label: const Text('New Note'),
          ),
        ],
      );
    }
    if (_currentTab == 1) {
      final peers = ref.watch(peersProvider).maybeWhen(data: (p) => p, orElse: () => <DiscoveredPeer>[]);
      if (peers.isEmpty) return null;
      return FloatingActionButton.extended(
        heroTag: 'share_fab',
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        onPressed: () => _showShareAllSheet(context, ref, peers),
        icon: const Icon(Icons.share_rounded),
        label: const Text('Share All'),
      );
    }
    return null;
  }

  String? _countBadge(WidgetRef ref, {required bool notes}) {
    if (notes) {
      final c = ref.watch(notesProvider).maybeWhen(data: (n) => n.length, orElse: () => 0);
      return c > 0 ? '$c' : null;
    } else {
      final c = ref.watch(peersProvider).maybeWhen(data: (p) => p.length, orElse: () => 0);
      return c > 0 ? '$c' : null;
    }
  }

  void _onShake(BuildContext context, WidgetRef ref) {
    HapticFeedback.heavyImpact();
    final peers = ref.read(peersProvider).maybeWhen(data: (p) => p, orElse: () => <DiscoveredPeer>[]);
    if (peers.isNotEmpty) {
      ref.read(shakeProvider.notifier).notifyPeerFound(peers.first);
    } else {
      ref.read(peersProvider.notifier).refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanning for nearby devices… 👀')),
      );
    }
  }

  void _showNfcSheet(BuildContext context) {
    showModalBottomSheet(context: context, builder: (_) => _NfcSheet());
  }

  void _showShareAllSheet(BuildContext context, WidgetRef ref, List peers) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share All Notes', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...peers.map((p) => ListTile(
              leading: CircleAvatar(backgroundColor: p.avatarColor,
                child: Text(p.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              title: Text(p.name),
              subtitle: Text('${p.noteCount} notes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(syncStateProvider.notifier).shareAllNotes(p);
              },
            )),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final int peerCount;
  final String? roomSsid;
  const _HeroHeader({required this.peerCount, this.roomSsid});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.primary.withOpacity(isDark ? 0.25 : 0.12), AppColors.secondary.withOpacity(0.05)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 30, height: 30,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.sync_alt, color: Colors.white, size: 16)),
            const SizedBox(width: 8),
            Text(AppStrings.appName, style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800, color: AppColors.primary)),
          ]),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _Pill('🔒 E2EE', AppColors.primary),
              const SizedBox(width: 6),
              _Pill('📴 Offline-First', AppColors.success),
              if (peerCount > 0) ...[const SizedBox(width: 6), _Pill('🚀 $peerCount nearby', AppColors.secondary)],
              if (roomSsid != null) ...[const SizedBox(width: 6), _Pill('🏢 $roomSsid', AppColors.tertiary)],
            ]),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String l; final Color c;
  const _Pill(this.l, this.c);
  @override
  Widget build(_) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.3))),
    child: Text(l, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
  );
}

class _TabLabel extends StatelessWidget {
  final IconData icon; final String label; final String? badge;
  const _TabLabel(this.icon, this.label, this.badge);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15),
      const SizedBox(width: 4),
      Flexible(
        child: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
      ),
      if (badge != null) ...[
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(badge!, style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    ],
  );
}

class _RoomJoinedBanner extends StatelessWidget {
  final String room;
  const _RoomJoinedBanner({required this.room});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: AppColors.success.withOpacity(0.1),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text('${AppStrings.roomAutoJoined}: $room',
          style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _NfcSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('📲', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text('NFC Tap-to-Share', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text(AppStrings.viral_nfc, textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, height: 1.4)),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Hold phones back-to-back…')));
          },
          icon: const Icon(Icons.nfc_rounded),
          label: const Text('Start NFC Handshake'),
        )),
      const SizedBox(height: 8),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
    ]),
  );
}
