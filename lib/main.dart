// DDE-Mart vendor app — entry point (original, clean-room rebuild).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

void main() {
  runApp(const ProviderScope(child: DdeVendorApp()));
}

class DdeVendorApp extends ConsumerWidget {
  const DdeVendorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'DDE Vendor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF7C3AED),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
