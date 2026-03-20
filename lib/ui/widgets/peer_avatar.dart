// lib/ui/widgets/peer_avatar.dart
import 'package:flutter/material.dart';
import '../../models/peer.dart';

class PeerAvatar extends StatelessWidget {
  final DiscoveredPeer peer;
  final double size;

  const PeerAvatar({super.key, required this.peer, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            peer.avatarColor.withOpacity(0.7),
            peer.avatarColor,
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          peer.initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36,
          ),
        ),
      ),
    );
  }
}
