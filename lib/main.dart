import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/config.dart';
import 'src/core/providers.dart';
import 'src/core/router.dart';
import 'src/core/theme_controller.dart';
import 'src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load .env (api_base, school code). Tolerate a missing file in dev.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {/* defaults in AppConfig apply */}
  runApp(const ProviderScope(child: EcoursaleApp()));
}

class EcoursaleApp extends ConsumerWidget {
  const EcoursaleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Server-driven theme: when the school config loads, the whole app re-themes
    // to the school's brand colour with NO rebuild. Falls back to a neutral theme
    // before it loads / when logged out.
    final config = ref.watch(schoolConfigProvider);
    final c = config.maybeWhen(data: (cfg) => cfg, orElse: () => null);
    // Server-driven brand colour + device-driven light/dark: the app follows the
    // phone's system brightness (themeMode.system) while keeping each school's
    // primary colour as the accent in BOTH light and dark.
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromConfig(c),
      darkTheme: AppTheme.darkFromConfig(c),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
