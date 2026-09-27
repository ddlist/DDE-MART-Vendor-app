// DDE-Mart vendor app — safePush guard tests (original).
//
// Every in-app destination is a shell branch; pushing one while the shell
// is stacked used to duplicate the shell match and crash the Navigator
// with `!keyReservation.contains(key)`. These flows must stay clean.

// ignore_for_file: avoid_print

import 'package:dde_vendor/core/nav.dart';
import 'package:dde_vendor/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shell flows never duplicate page keys', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, r, _) {
            return MaterialApp.router(
                routerConfig: r.watch(routerProvider));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    BuildContext ctx() => tester.element(find.byType(Scaffold).first);

    Future<void> go(String location) async {
      ctx().safePush(location);
      await tester.pumpAndSettle();
    }

    await go('/orders');
    await go('/catalog');
    await go('/catalog/new');
    await go('/catalog');
    await go('/coupons');
    await go('/coupons/new');
    await go('/chat');
    await go('/payouts');
    await go('/profile');
    await go('/orders');
    await go('/dinein');
  });
}
