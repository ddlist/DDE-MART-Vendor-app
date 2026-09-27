// DDE-Mart vendor app — navigation guard (original).
//
// GoRouter keys pages by matched location, and pushing a location that also
// matches under the ShellRoute merges a SECOND shell match into the list —
// both shells share one page key, crashing the Navigator with
// `!keyReservation.contains(key)`. In this app every in-app destination is
// a shell branch, so they are always reached with [go] (rebuild, never
// duplicate). Anything else is pushed, with sub-second repeats dropped.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Shell-branch destinations (must stay in sync with the [ShellRoute] in
/// router.dart): orders, dine-in, catalog (+editors), coupons (+editor),
/// chat (+threads), subscription, payouts, profile.
const _shellDestinations = {
  '/orders',
  '/dinein',
  '/catalog',
  '/catalog/new',
  '/coupons',
  '/coupons/new',
  '/chat',
  '/subscription',
  '/payouts',
  '/profile',
};

bool _isShellDestination(String location) {
  if (_shellDestinations.contains(location)) return true;
  return location.startsWith('/catalog/product/') ||
      location.startsWith('/chat/');
}

DateTime? _lastPushAt;
String? _lastPushTo;

extension SafeNav on BuildContext {
  void safePush(String location, {Object? extra}) {
    if (_isShellDestination(location)) {
      go(location, extra: extra);
      return;
    }
    final router = GoRouter.of(this);
    final stacked = router.routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .contains(location);
    if (stacked) {
      go(location);
      return;
    }
    final now = DateTime.now();
    if (_lastPushTo == location &&
        _lastPushAt != null &&
        now.difference(_lastPushAt!).inMilliseconds < 800) {
      return;
    }
    _lastPushTo = location;
    _lastPushAt = now;
    push(location, extra: extra);
  }
}
