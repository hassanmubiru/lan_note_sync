# 🔄 LanNote Sync

> **Private, encrypted, peer-to-peer note sharing over your local network.**  
> No cloud. No accounts. No data leaving your Wi-Fi.

![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter)
![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-brightgreen)
![License](https://img.shields.io/badge/License-MIT-blue)

---

## ✨ Features

| Feature | Native (Android/iOS/Desktop) | Web |
|---------|--------------------------|-----|
| Discovery | mDNS / Bonsoir | Socket.IO signaling |
| Transport | HTTP + WebSocket (Shelf) | WebRTC DataChannel |
| Encryption | AES-256-GCM + RSA-2048 | AES-256-GCM + RSA-2048 |
| Storage | Hive (encrypted) | Hive (encrypted) |
| Markdown | ✅ | ✅ |
| Images | ✅ Base64 embedded | ✅ Base64 embedded |
| Conflict UI | Side-by-side merge | Side-by-side merge |
| Offline-first | ✅ | ✅ |

---

## 🏗️ Architecture

```
lib/
├── core/
│   ├── constants.dart      # App-wide config (ports, keys, colors)
│   ├── router.dart         # GoRouter navigation
│   └── theme.dart          # Material 3 + glass morphism theme
│
├── models/
│   ├── note.dart           # Note model + Hive adapter
│   └── peer.dart           # Peer model + sync message types
│
├── services/
│   ├── storage/
│   │   └── hive_service.dart       # Encrypted local storage
│   ├── crypto/
│   │   └── crypto_service.dart     # RSA + AES-256-GCM E2E encryption
│   ├── network/
│   │   ├── http_server_service.dart # Shelf HTTP + WebSocket server
│   │   ├── mdns_service.dart        # Bonsoir mDNS discovery (native)
│   │   └── webrtc_service.dart      # WebRTC + Socket.IO (web)
│   ├── sync/
│   │   └── sync_service.dart        # Bidirectional sync + conflict resolution
│   └── device_service.dart          # Device name/ID management
│
├── providers/
│   ├── notes_provider.dart   # Riverpod: notes CRUD, search, sort
│   └── peers_provider.dart   # Riverpod: discovery, sync state
│
├── ui/
│   ├── screens/
│   │   ├── home/            # TabBar (My Notes | Nearby)
│   │   ├── editor/          # Markdown note editor
│   │   ├── peer/            # Peer detail + remote notes
│   │   ├── conflict/        # Side-by-side conflict resolution
│   │   └── settings/        # Theme, device name, QR, etc.
│   └── widgets/
│       ├── note_card.dart         # Swipe-to-delete card
│       ├── peer_card.dart         # Animated peer card
│       ├── peer_avatar.dart       # Colored initials avatar
│       ├── skeleton_loader.dart   # Shimmer loading states
│       ├── empty_state.dart       # Empty list illustration
│       └── sync_status_bar.dart   # Live sync progress bar
│
└── main.dart               # App entry + Riverpod + Router

signaling_server/
├── server.js               # Node.js Socket.IO signaling server
├── package.json
└── Dockerfile

docker-compose.yml          # Full stack: signaling + Flutter web
```

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.24+ (`flutter --version`)
- Dart 3.3+
- Node.js 18+ (for signaling server)
- Xcode 15+ (iOS/macOS)
- Android Studio / SDK (Android)

---

### 1. Clone & Install

```bash
git clone <repo-url> lan_note_sync
cd lan_note_sync
flutter pub get
```

### 2. Run on Android (same Wi-Fi as another device)

```bash
flutter run -d android
```

### 3. Run on iOS

```bash
flutter run -d ios
```

> **iOS Note:** You may need to accept the local network permission dialog on first launch.

### 4. Run on Web + Signaling Server

**Terminal 1 — Start signaling server:**
```bash
cd signaling_server
npm install
npm start
# ✅ Running on port 3031
```

**Terminal 2 — Run Flutter web:**
```bash
flutter run -d chrome \
  --dart-define=SIGNALING_URL=http://localhost:3031
```

Or build for production:
```bash
flutter build web --release
cd signaling_server && npm start &
python3 -m http.server 8080 --directory ../build/web
```

### 5. Run on macOS / Windows / Linux

```bash
flutter run -d macos     # macOS
flutter run -d windows   # Windows
flutter run -d linux     # Linux
```

---

### 6. Docker (Full Stack)

```bash
# Build Flutter web first
flutter build web --release

# Start everything
docker-compose up -d

# Access at:
# → Flutter web:  http://localhost:8080
# → Signaling:    http://localhost:3031/health
```

---

## 🔐 Security Model

```
Device A                          Device B
────────                          ────────
1. RSA-2048 key pair generated    1. RSA-2048 key pair generated
2. Public key broadcast via mDNS  2. Public key broadcast via mDNS
3. Connect → exchange public keys
4. Generate AES-256 session key   4. Encrypt session key w/ B's pubkey
5. Encrypt notes w/ session key   5. Decrypt session key w/ private key
6. Transmit encrypted payload     6. Decrypt notes w/ session key
```

- **At rest:** Hive box encrypted with AES-256 (key stored in secure storage)
- **In transit:** AES-256-GCM with per-session keys, RSA-2048 key exchange
- **No cloud:** All traffic stays on your LAN — nothing touches the internet

---

## 📡 Network Protocol

### Native (mDNS + HTTP)

```
_lanNote._tcp service broadcast on port 3030
TXT records: deviceId, deviceName, noteCount, platform, version

HTTP Endpoints:
  GET  /info          → device metadata
  GET  /ping          → health check  
  GET  /notes         → note metadata list (id, title, version, tags)
  POST /share         → receive notes from peer (JSON body)
  GET  /sync          → WebSocket upgrade for real-time sync
```

### Web (WebRTC + Socket.IO)

```
Socket.IO events (client → server):
  announce       → register presence
  offer          → WebRTC offer (routed to target peer)
  answer         → WebRTC answer
  ice-candidate  → ICE candidate exchange

WebRTC DataChannel 'notes-json':
  hello          → device info handshake
  requestNotes   → ask peer for specific notes
  sendNotes      → push notes to peer
```

---

## 🎨 UI/UX Highlights

- **Material 3** with custom Indigo palette (`#6366F1`)
- **Glass morphism** cards with backdrop blur
- **Swipe-to-delete** notes with confirmation
- **Skeleton loaders** during discovery/loading
- **Animated peer discovery** with pulsing dot
- **Real-time sync bar** with progress tracking
- **Dark mode** fully supported
- **Haptic feedback** on share success

---

## 🧪 Test Scenarios

### 1. Two phones, same Wi-Fi
```
Phone A: flutter run -d android
Phone B: flutter run -d ios
→ Should see each other in "Nearby" tab within ~5 seconds
→ Tap "Sync" → notes appear on both devices
```

### 2. Mobile + Web (same network)
```
Terminal: cd signaling_server && npm start
Browser:  flutter run -d chrome
Phone:    flutter run -d android
→ Mobile sees web client in Nearby tab
→ WebRTC handshake should complete in <3s
```

### 3. Conflict resolution
```
1. Create note "Meeting Notes" on Phone A
2. Sync to Phone B
3. Edit note on BOTH phones while offline
4. Reconnect and sync
→ Conflict screen appears with side-by-side diff
→ Choose "Keep Mine", "Keep Theirs", or manually merge
```

---

## 🔧 Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `servicePort` | `3030` | HTTP server port for native |
| `serviceType` | `_lanNote._tcp` | mDNS service type |
| `signalingUrl` | `http://localhost:3031` | WebRTC signaling server |
| `maxImageSize` | `5MB` | Max image attachment size |
| `maxTagsPerNote` | `20` | Tags limit per note |
| `syncTimeout` | `30s` | Network operation timeout |

---

## 🐛 Troubleshooting

**Devices not discovering each other:**
- Ensure both on same Wi-Fi (not guest network)
- Check firewall allows port 3030
- Android: Accept "Nearby devices" permission prompt
- iOS: Accept "Local Network" permission dialog

**mDNS not working on Android 12+:**
- App requests `CHANGE_WIFI_MULTICAST_STATE` automatically
- Some Android ROMs block mDNS — use Manual Connect as fallback

**WebRTC connection failing:**
- Verify signaling server is running (`curl http://localhost:3031/health`)
- Check CORS — signaling server allows `*` by default
- Try on same subnet (WebRTC ICE filtering removes relay candidates)

**Images not displaying:**
- Base64 images are stored inline — large images slow sync
- Max image size is 5MB per image

---

## 📦 Key Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | Reactive state management |
| `bonsoir` | mDNS service discovery & broadcast |
| `flutter_webrtc` | WebRTC P2P data channels |
| `socket_io_client` | Socket.IO for WebRTC signaling |
| `hive_flutter` | Fast encrypted local storage |
| `shelf` + `shelf_router` | Embedded HTTP server |
| `pointycastle` | RSA-2048 + AES-256-GCM crypto |
| `flutter_markdown` | Markdown rendering |
| `flutter_animate` | Declarative animations |
| `go_router` | Declarative navigation |
| `qr_flutter` | QR code generation |

---

## 📄 License

MIT — see [LICENSE](LICENSE)

---

*Built with Flutter 3.24 · Riverpod 2.5 · Material 3*
