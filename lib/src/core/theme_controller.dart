import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The user's app-theme preference: follow the phone (System), or force Light /
/// Dark regardless of the phone setting. Persisted so it survives restarts.
///
/// Default is System (the app follows the device light/dark). The user can
/// override it under Profile → Appearance.
class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController(this._storage) : super(ThemeMode.system) {
    _load();
  }

  final FlutterSecureStorage _storage;
  static const _key = 'theme_mode';

  Future<void> _load() async {
    final v = await _storage.read(key: _key);
    state = _parse(v);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _storage.write(key: _key, value: mode.name);
  }

  static ThemeMode _parse(String? v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeController, ThemeMode>(
  (ref) => ThemeController(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  ),
);
