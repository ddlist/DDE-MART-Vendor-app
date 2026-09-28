// DDE-Mart vendor app — dine-in inbox (original).
//
// GET /vendor/dinein (own stores) + POST /vendor/dinein/{id}/transition.
// Machine: pending → confirmed|cancelled, confirmed → seated|cancelled,
// seated → completed.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';

class DineinBooking {
  DineinBooking({
    required this.id,
    required this.guest,
    required this.guests,
    required this.status,
  });

  factory DineinBooking.fromJson(Map<String, dynamic> json) => DineinBooking(
        id: json['id'] as int,
        guest: '${json['guest'] ?? ''}',
        guests: (json['guests'] as num?)?.toInt() ?? 0,
        status: '${json['status']}',
      );

  final int id;
  final String guest;
  final int guests;
  final String status;
}

class DineinApi {
  DineinApi(this._dio);

  final Dio _dio;

  Future<List<DineinBooking>> bookings() async {
    final response = await _dio.get('/vendor/dinein');
    final data = ((response.data as Map)['data'] as List?) ?? [];
    return data
        .map((e) => DineinBooking.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> transition({required int id, required String to}) async {
    await _dio.post('/vendor/dinein/$id/transition', data: {'to': to});
  }
}

final dineinApiProvider = Provider<DineinApi>(
  (ref) => DineinApi(ref.watch(dioProvider)),
);

final dineinProvider = FutureProvider<List<DineinBooking>>((ref) async {
  return ref.watch(dineinApiProvider).bookings();
});

String _prettyMove(String move) {
  if (move.length <= 4) return move.toUpperCase();
  return move.replaceAll('_', ' ');
}

/// Legal next moves per status (mirrors the backend machine).
List<String> nextMoves(String status) {
  return switch (status) {
    'pending' => ['confirmed', 'cancelled'],
    'confirmed' => ['seated', 'cancelled'],
    'seated' => ['completed'],
    _ => [],
  };
}

class DineinScreen extends ConsumerStatefulWidget {
  const DineinScreen({super.key});

  @override
  ConsumerState<DineinScreen> createState() => _DineinScreenState();
}

class _DineinScreenState extends ConsumerState<DineinScreen> {
  bool _busy = false;

  Future<void> _move(DineinBooking booking, String to) async {
    setState(() => _busy = true);
    try {
      await ref.read(dineinApiProvider).transition(id: booking.id, to: to);
      ref.invalidate(dineinProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(dineinProvider);

    return bookings.when(
      loading: () => const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: ShimmerList(rows: 4),
      ),
      error: (e, _) => ErrorRetry(
        error: e,
        onRetry: () => ref.invalidate(dineinProvider),
      ),
      data: (rows) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(dineinProvider),
        child: rows.isEmpty
            ? const EmptyState(
                message: 'No table bookings yet.',
                icon: Icons.table_restaurant_outlined,
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const GradientHeader(
                    title: 'Dine-in',
                    subtitle: 'Confirm arrivals, seat guests, close out.',
                    icon: Icons.table_restaurant_outlined,
                  ),
                  const SizedBox(height: 12),
                  for (final booking in rows)
                    SleekCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${booking.guest} · party of ${booking.guests}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              StatusChip(status: booking.status),
                            ],
                          ),
                          if (nextMoves(booking.status).isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final move
                                    in nextMoves(booking.status))
                                  FilledButton.tonal(
                                    onPressed: _busy
                                        ? null
                                        : () => _move(booking, move),
                                    child: Text(_prettyMove(move)),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
