// DDE-Mart vendor app — dine-in machine + gate unit tests (original).

import 'package:dde_vendor/core/gate.dart';
import 'package:dde_vendor/features/dinein/dinein.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gateStatus', () {
    test('maintenance wins', () {
      expect(
        gateStatus(current: '9.9.9', minimum: '1.0.0', maintenance: true),
        GateDecision.maintenance,
      );
    });

    test('older app requires update, equal passes', () {
      expect(
        gateStatus(current: '1.0.0', minimum: '2.0.0', maintenance: false),
        GateDecision.updateRequired,
      );
      expect(
        gateStatus(current: '2.0.0', minimum: '2.0.0', maintenance: false),
        GateDecision.ok,
      );
    });
  });

  group('nextMoves', () {
    test('pending and confirmed branches', () {
      expect(nextMoves('pending'), ['confirmed', 'cancelled']);
      expect(nextMoves('confirmed'), ['seated', 'cancelled']);
    });

    test('seated completes, terminal states rest', () {
      expect(nextMoves('seated'), ['completed']);
      expect(nextMoves('completed'), isEmpty);
      expect(nextMoves('cancelled'), isEmpty);
      expect(nextMoves('bogus'), isEmpty);
    });
  });
}
