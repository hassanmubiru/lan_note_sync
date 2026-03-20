// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage/hive_service.dart';

final themeProvider = StateProvider<ThemeMode>((ref) {
  final saved = HiveService.getSetting<String>('theme') ?? 'system';
  switch (saved) {
    case 'light':  return ThemeMode.light;
    case 'dark':   return ThemeMode.dark;
    default:       return ThemeMode.system;
  }
});
