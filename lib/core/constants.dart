// lib/core/constants.dart
import 'package:flutter/material.dart';

class AppConstants {
  // Service Discovery
  static const String serviceType = '_lanNote._tcp';
  static const int servicePort = 3030;
  static const String serviceName = 'LanNoteSync';

  // HTTP Endpoints
  static const String endpointNotes   = '/notes';
  static const String endpointShare   = '/share';
  static const String endpointInfo    = '/info';
  static const String endpointPing    = '/ping';
  static const String endpointCursor  = '/cursor';
  static const String wsPath          = '/sync';

  // Hive Boxes
  static const String notesBox    = 'notes';
  static const String settingsBox = 'settings';
  static const String roomsBox    = 'rooms';

  // Encryption
  static const String encryptionKeyPref = 'hive_encryption_key';
  static const int keyLength = 32;

  // Sync
  static const Duration discoveryTimeout  = Duration(seconds: 10);
  static const Duration syncTimeout       = Duration(seconds: 30);
  static const Duration heartbeatInterval = Duration(seconds: 15);
  static const int maxNotesPerBatch = 50;

  // Shake detection
  static const double shakeThreshold     = 15.0;  // m/s²
  static const int shakeMinInterval      = 1000;   // ms between shakes

  // NFC
  static const String nfcRecordType = 'application/vnd.lannote.handshake';

  // Signaling
  // Public signaling server — change to your own for production
  // For local development: 'http://localhost:3031'
  static const String defaultSignalingUrl = 'https://lannote-signal.fly.dev';
  static const String fallbackSignalingUrl = 'http://localhost:3031';
  static const String signalingPath       = '/socket.io';

  // IAP Product IDs
  static const String iapProPeers     = 'lannote_pro_peers';
  static const String iapVoice        = 'lannote_voice';
  static const String iapAR           = 'lannote_ar';
  static const String iapEnterprise   = 'lannote_enterprise';
  static const String revenueCatKey   = 'YOUR_REVENUECAT_KEY'; // replace

  // Note limits
  static const int maxTitleLength        = 200;
  static const int maxContentLength      = 100000;
  static const int maxTagsPerNote        = 20;
  static const int maxImageSizeBytes     = 5 * 1024 * 1024;
  static const int freePeerLimit         = 5;

  // Animations
  static const Duration animationFast   = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 350);
  static const Duration animationSlow   = Duration(milliseconds: 600);
}

// ─── Color palette ──────────────────────────────────────────────────────────

class AppColors {
  // Primary
  static const Color primary      = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark  = Color(0xFF4F46E5);

  // Accents
  static const Color secondary = Color(0xFF10B981);
  static const Color tertiary  = Color(0xFFF59E0B);
  static const Color error     = Color(0xFFEF4444);
  static const Color success   = Color(0xFF22C55E);
  static const Color warning   = Color(0xFFF97316);
  static const Color neon      = Color(0xFF00F5FF); // viral / AR accent

  // Surfaces (light)
  static const Color surfaceLight = Color(0xFFF8F9FF);
  static const Color cardLight    = Color(0xFFFFFFFF);
  static const Color borderLight  = Color(0xFFE5E7EB);

  // Surfaces (dark)
  static const Color surfaceDark = Color(0xFF0A0F1E);
  static const Color cardDark    = Color(0xFF141929);
  static const Color borderDark  = Color(0xFF1E2940);

  // Glass morphism
  static const Color glassLight = Color(0x99FFFFFF);
  static const Color glassDark  = Color(0x33FFFFFF);

  // Gradients
  static const List<Color> heroGradient = [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF06B6D4)];
  static const List<Color> dangerGradient = [Color(0xFFEF4444), Color(0xFFEC4899)];
  static const List<Color> successGradient = [Color(0xFF10B981), Color(0xFF06B6D4)];

  // Tag palette
  static const List<Color> tagColors = [
    Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFF59E0B),
    Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF06B6D4),
    Color(0xFFEC4899), Color(0xFF14B8A6),
  ];
}

// ─── Copy strings ────────────────────────────────────────────────────────────

class AppStrings {
  static const String appName    = 'LanNote Sync';
  static const String tagline    = 'Zero-cloud. Offline-first. Boss-proof.';
  static const String antiCloud  = 'Unlike Evernote, we NEVER read your notes.';

  // Security badges
  static const String badge_e2ee    = '🔒 E2EE Active';
  static const String badge_offline = '📴 Offline-First';
  static const String badge_notrack = '✅ No Tracking';

  // Viral hooks
  static const String viral_shake   = '👋 Shake to find teammates';
  static const String viral_speed   = 'Notes synced in ';
  static const String viral_bossproof = 'Boss-proof mode activated 😈';
  static const String viral_qr      = 'Scan me to sync notebooks!';
  static const String viral_nfc     = 'Tap phones to share instantly';

  // Tabs
  static const String myNotes  = 'My Notes';
  static const String nearby   = 'Nearby';
  static const String rooms    = 'Rooms';

  // Room mode
  static const String roomAutoJoined  = 'Auto-joined room';
  static const String roomEmpty       = 'No rooms detected nearby.\nChange WiFi networks to auto-join.';

  // Voice
  static const String voiceListening  = 'Listening...';
  static const String voiceProcessing = 'Transcribing locally...';
  static const String voiceDone       = 'Transcription complete ✓';

  // IAP
  static const String iapFreeForever  = '🎉 Free Forever';
  static const String iapPro          = '🚀 Pro — Unlimited Peers';
  static const String iapVoice        = '🎙️ Voice — Local Transcription';
  static const String iapAR           = '🔮 AR — Whiteboard Capture';
  static const String iapEnterprise   = '🏢 Enterprise — 500 Peers + NFC';
}
