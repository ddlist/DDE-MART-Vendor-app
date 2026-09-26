// DDE-Mart vendor app — shell, router + launch gate (original).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/api_client.dart';
import 'core/auth_store.dart';
import 'core/config.dart';
import 'core/gate.dart';
import 'features/account/payouts_profile.dart';
import 'features/auth/vendor_login_screen.dart';
import 'features/catalog/catalog.dart';
import 'features/catalog/product_editor.dart';
import 'features/dinein/dinein.dart';
import 'features/orders/orders.dart';

final launchGateProvider = FutureProvider<GateDecision>((ref) async {
  final dio = ref.watch(dioProvider);
  final info = await PackageInfo.fromPlatform();

  try {
    final response = await dio.get('/app-config');
    final config = LaunchConfig.fromJson(
      Map<String, dynamic>.from((response.data as Map)['data'] as Map),
    );
    return gateStatus(
      current: info.version,
      minimum: config.minVersions[AppConfig.audience] ?? '1.0.0',
      maintenance: config.maintenance,
    );
  } on DioException {
    return GateDecision.ok;
  }
});

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStoreProvider);
  final gate = ref.watch(launchGateProvider);

  return GoRouter(
    initialLocation: '/orders',
    redirect: (context, state) {
      final location = state.matchedLocation;

      if (gate.valueOrNull == GateDecision.maintenance && location != '/maintenance') {
        return '/maintenance';
      }
      if (gate.valueOrNull == GateDecision.updateRequired && location != '/update') {
        return '/update';
      }

      const public = ['/login', '/maintenance', '/update'];
      if (!auth.signedIn && !public.any(location.startsWith)) {
        return '/login';
      }
      if (auth.signedIn && (location == '/login' || location == '/')) {
        return '/orders';
      }
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => VendorShell(child: child),
        routes: [
          GoRoute(path: '/orders', builder: (context, state) => const OrdersScreen()),
          GoRoute(path: '/dinein', builder: (context, state) => const DineinScreen()),
          GoRoute(path: '/catalog', builder: (context, state) => const CatalogScreen()),
          GoRoute(
            path: '/catalog/new',
            builder: (context, state) => const ProductEditorScreen(),
          ),
          GoRoute(
            path: '/catalog/product/:id',
            builder: (context, state) => ProductEditorScreen(
              product: state.extra as Map<String, dynamic>?,
            ),
          ),
          GoRoute(path: '/payouts', builder: (context, state) => const VendorPayoutsScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const VendorProfileScreen()),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const VendorLoginScreen()),
      GoRoute(path: '/maintenance', builder: (context, state) => const MaintenanceScreen()),
      GoRoute(path: '/update', builder: (context, state) => const UpdateScreen()),
    ],
  );
});

class VendorShell extends StatelessWidget {
  const VendorShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    var index = 0;
    if (location.startsWith('/dinein')) {
      index = 1;
    } else if (location.startsWith('/catalog')) {
      index = 2;
    } else if (location.startsWith('/payouts')) {
      index = 3;
    } else if (location.startsWith('/profile')) {
      index = 4;
    }

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          switch (value) {
            case 0:
              context.go('/orders');
            case 1:
              context.go('/dinein');
            case 2:
              context.go('/catalog');
            case 3:
              context.go('/payouts');
            case 4:
              context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.table_restaurant_outlined), label: 'Dine-in'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Catalog'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Payouts'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 64),
              const SizedBox(height: 16),
              const Text('DDE-Mart is under maintenance', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(launchGateProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update_outlined, size: 64),
              SizedBox(height: 16),
              Text('Please update DDE Vendor to continue.', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
