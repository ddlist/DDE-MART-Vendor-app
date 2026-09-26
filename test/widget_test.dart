// DDE-Mart vendor app — smoke test (original).

import 'package:dde_vendor/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots to vendor sign-in offline', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DdeVendorApp()));
    await tester.pumpAndSettle();

    expect(find.text('Vendor sign in'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
