// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'services/storage/hive_service.dart';
import 'services/device_service.dart';
import 'services/crypto/crypto_service.dart';
import 'services/purchase/purchase_service.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Boot sequence
  await HiveService.initialize();
  await DeviceService.initialize();
  await CryptoService.initialize();
  await PurchaseService.initialize(); // RevenueCat (no-op in dev mode)

  runApp(const ProviderScope(child: LanNoteSyncApp()));
}

class LanNoteSyncApp extends ConsumerWidget {
  const LanNoteSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
    );
  }
}
