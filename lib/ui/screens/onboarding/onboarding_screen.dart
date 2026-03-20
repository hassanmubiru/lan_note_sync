// lib/ui/screens/onboarding/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../services/storage/hive_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  final _pages = const [
    _OnboardPage(
      emoji: '🔒',
      title: 'Your Notes Are Sacred',
      subtitle: 'Unlike Evernote or Notion,\nwe NEVER read your notes.',
      detail: 'End-to-end encrypted. Local-only.\nNo servers. No accounts. No snooping.',
      gradient: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    ),
    _OnboardPage(
      emoji: '📴',
      title: 'Works in Airplane Mode',
      subtitle: 'The only notes app that works\nwhen the internet dies.',
      detail: 'Share notes with teammates in dead WiFi zones,\nbasements, and conference rooms.',
      gradient: [Color(0xFF10B981), Color(0xFF06B6D4)],
    ),
    _OnboardPage(
      emoji: '👋',
      title: 'Shake to Share',
      subtitle: 'Shake your phone to instantly\ndiscover nearby teammates.',
      detail: 'NFC tap, QR scan, or just shake — \nyour notes fly between devices in seconds.',
      gradient: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ),
    _OnboardPage(
      emoji: '🚀',
      title: 'Team Rooms. No Setup.',
      subtitle: 'Same WiFi = Same room.\nAuto-join. Auto-sync.',
      detail: 'Walk into "Meeting Room Alpha" WiFi\nand your whole team is already synced.',
      gradient: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ..._pages[_page].gradient,
                  Colors.black,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Page content
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              final p = _pages[index];
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // Emoji hero
                      Text(
                        p.emoji,
                        style: const TextStyle(fontSize: 80),
                      )
                          .animate(key: ValueKey('emoji$index'))
                          .scale(begin: const Offset(0.5, 0.5), duration: 500.ms, curve: Curves.elasticOut)
                          .fadeIn(),

                      const SizedBox(height: 32),

                      // Title
                      Text(
                        p.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      )
                          .animate(key: ValueKey('title$index'))
                          .fadeIn(delay: 150.ms)
                          .slideY(begin: 0.2),

                      const SizedBox(height: 16),

                      // Subtitle
                      Text(
                        p.subtitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      )
                          .animate(key: ValueKey('sub$index'))
                          .fadeIn(delay: 250.ms),

                      const SizedBox(height: 20),

                      // Detail
                      Text(
                        p.detail,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 14,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      )
                          .animate(key: ValueKey('det$index'))
                          .fadeIn(delay: 350.ms),

                      const Spacer(flex: 3),
                    ],
                  ),
                ),
              );
            },
          ),

          // Bottom nav
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  children: [
                    // Page dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? Colors.white : Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )),
                    ),
                    const SizedBox(height: 24),

                    // CTA button
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _page == _pages.length - 1
                          ? _GetStartedButton(onTap: _finish)
                          : _NextButton(onTap: _nextPage),
                    ),

                    const SizedBox(height: 12),

                    // Skip
                    if (_page < _pages.length - 1)
                      TextButton(
                        onPressed: _finish,
                        child: Text('Skip', style: TextStyle(color: Colors.white54, fontSize: 14)),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Security badges — always visible
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MicroBadge('🔒 E2EE'),
                    const SizedBox(width: 8),
                    _MicroBadge('📴 Offline'),
                    const SizedBox(width: 8),
                    _MicroBadge('✅ No Tracking'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    await HiveService.setSetting('onboarding_done', true);
    if (mounted) context.go('/');
  }
}

class _OnboardPage {
  final String emoji, title, subtitle, detail;
  final List<Color> gradient;
  const _OnboardPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.gradient,
  });
}

class _NextButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NextButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Next', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GetStartedButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 12,
          shadowColor: AppColors.primary.withOpacity(0.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Get Started — Free Forever', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _MicroBadge extends StatelessWidget {
  final String label;
  const _MicroBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
