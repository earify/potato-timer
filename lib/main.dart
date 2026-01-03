import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'data/theme_provider.dart';
import 'screens/home_page.dart';
import 'firebase_options.dart';
import 'data/providers.dart';

import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import 'utils/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await localNotifier.setup(
      appName: 'Potato',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );
  }

  await NotificationService().init();

  try {
    // Initialize Firebase with the generated options.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
  runApp(const ProviderScope(child: PotatoApp()));
}

class PotatoApp extends ConsumerWidget {
  const PotatoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeProvider);

    // Initial sync check when syncRepository becomes available (user logs in)
    ref.listen(syncRepositoryProvider, (previous, next) {
      if (next != null && previous == null) {
        next.syncAll().catchError((e) => debugPrint('Initial sync failed: $e'));
      }
    });

    return MaterialApp(
      title: 'Potato',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeSettings.seedColor,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeSettings.seedColor,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: themeSettings.mode,
      home: const HomePage(),
    );
  }
}
