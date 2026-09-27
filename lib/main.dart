// DDE-Mart vendor app — entry point (original, clean-room rebuild).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push.dart';
import 'core/theme.dart';
import 'router.dart';

void main() {
  runApp(const ProviderScope(child: DdeVendorApp()));
}

class DdeVendorApp extends ConsumerWidget {
  const DdeVendorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Instantiates the session watcher; syncs push once per sign-in.
    ref.watch(pushSyncProvider);

    return MaterialApp.router(
      title: 'DDE Vendor',
      debugShowCheckedModeBanner: false,
      theme: DdeVendorTheme.light(),
      darkTheme: DdeVendorTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}
