// lib/ui/screens/settings/settings_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants.dart';
import '../../../providers/peers_provider.dart';
import '../../../providers/notes_provider.dart';
import '../../../services/device_service.dart';
import '../../../services/storage/hive_service.dart';
import '../../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _signalingCtrl = TextEditingController();
  bool _isEditingName = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = DeviceService.deviceName;
    _signalingCtrl.text = ref.read(signalingUrlProvider);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _signalingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final signalingUrl = ref.watch(signalingUrlProvider);
    final noteCount = ref.watch(notesProvider).maybeWhen(data: (n) => n.length, orElse: () => 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Device ──────────────────────────────────────────────────────
          _SectionHeader('Device'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Device Avatar Preview
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: Text(
                          DeviceService.deviceName.isNotEmpty
                              ? DeviceService.deviceName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isEditingName)
                              TextField(
                                controller: _nameCtrl,
                                autofocus: true,
                                style: theme.textTheme.titleMedium,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                onSubmitted: _saveName,
                              )
                            else
                              Text(
                                DeviceService.deviceName,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            Text(
                              DeviceService.platform.toUpperCase(),
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(_isEditingName ? Icons.check : Icons.edit_outlined),
                        onPressed: () {
                          if (_isEditingName) {
                            _saveName(_nameCtrl.text);
                          } else {
                            setState(() => _isEditingName = true);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Device ID
                  Text('Device ID', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 2),
                  SelectableText(
                    DeviceService.deviceId,
                    style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Appearance ───────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Theme'),
                  trailing: DropdownButton<ThemeMode>(
                    value: themeMode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                      DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                    ],
                    onChanged: (m) async {
                      if (m == null) return;
                      ref.read(themeProvider.notifier).state = m;
                      final key = m == ThemeMode.light ? 'light' : m == ThemeMode.dark ? 'dark' : 'system';
                      await HiveService.setSetting('theme', key);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Network ───────────────────────────────────────────────────────
          _SectionHeader('Network'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.wifi_rounded),
                  title: const Text('Service port'),
                  trailing: Text(
                    '${AppConstants.servicePort}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.broadcast_on_personal),
                  title: const Text('mDNS service type'),
                  trailing: Text(
                    AppConstants.serviceType,
                    style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
                if (kIsWeb) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud_outlined),
                    title: const Text('Signaling server URL'),
                    subtitle: Text(signalingUrl, style: theme.textTheme.bodySmall),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () => _editSignalingUrl(context),
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.qr_code_rounded),
                  title: const Text('Show QR code'),
                  subtitle: const Text('Let other devices scan to connect'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showQrCode(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Data ──────────────────────────────────────────────────────────
          _SectionHeader('Data'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.note_alt_outlined),
                  title: const Text('Notes stored'),
                  trailing: Text(
                    '$noteCount',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.error),
                  title: const Text('Clear all notes',
                      style: TextStyle(color: AppColors.error)),
                  onTap: () => _confirmClearNotes(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader('About'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sync_alt, color: Colors.white, size: 18),
                  ),
                  title: const Text(AppStrings.appName),
                  subtitle: const Text(AppStrings.tagline),
                  trailing: const Text('v1.0.0',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('End-to-end encrypted'),
                  subtitle: const Text('Notes never leave your local network'),
                  trailing: Icon(Icons.check_circle, color: AppColors.success, size: 18),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_off_outlined),
                  title: const Text('No cloud sync'),
                  subtitle: const Text('Fully local, fully private'),
                  trailing: Icon(Icons.check_circle, color: AppColors.success, size: 18),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _saveName(String name) async {
    if (name.trim().isEmpty) return;
    await DeviceService.setCustomName(name.trim());
    setState(() => _isEditingName = false);
  }

  void _editSignalingUrl(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Signaling server URL'),
        content: TextField(
          controller: _signalingCtrl,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.x:3031',
            labelText: 'URL',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final url = _signalingCtrl.text.trim();
              if (url.isNotEmpty) {
                ref.read(signalingUrlProvider.notifier).state = url;
                HiveService.setSetting('signaling_url', url);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showQrCode(BuildContext context) {
    final port = AppConstants.servicePort;
    // The QR data encodes the device ID and port for manual connection
    final qrData = 'lannote://${DeviceService.deviceId}:$port';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan to connect'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: qrData, size: 200, backgroundColor: Colors.white),
            const SizedBox(height: 12),
            Text(
              'Scan with another LanNote device\nto connect directly',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SelectableText(
              DeviceService.deviceId,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _confirmClearNotes(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notes?'),
        content: const Text(
          'This will permanently delete ALL your notes. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HiveService.deleteAllNotes();
      await ref.read(notesProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notes deleted')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
