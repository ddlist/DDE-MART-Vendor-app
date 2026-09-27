// DDE-Mart vendor app — orders inbox (original).
//
// GET /vendor/orders (own stores) + POST /vendor/orders/{id}/transition
// {to: accepted|cancelled}. Placed orders show both actions.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';

class VendorOrder {
  VendorOrder({
    required this.id,
    required this.number,
    required this.customer,
    required this.total,
    required this.status,
  });

  factory VendorOrder.fromJson(Map<String, dynamic> json) => VendorOrder(
        id: json['id'] as int,
        number: '${json['number'] ?? ''}',
        customer: '${json['customer'] ?? ''}',
        total: (json['total'] as num?)?.toDouble() ?? 0,
        status: '${json['status']}',
      );

  final int id;
  final String number;
  final String customer;
  final double total;
  final String status;
}

class OrdersApi {
  OrdersApi(this._dio);

  final Dio _dio;

  Future<List<VendorOrder>> orders() async {
    final response = await _dio.get('/vendor/orders');
    final data = ((response.data as Map)['data'] as List?) ?? [];
    return data
        .map((e) => VendorOrder.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> transition({required int id, required String to}) async {
    await _dio.post('/vendor/orders/$id/transition', data: {'to': to});
  }
}

final ordersApiProvider = Provider<OrdersApi>(
  (ref) => OrdersApi(ref.watch(dioProvider)),
);

final ordersProvider = FutureProvider<List<VendorOrder>>((ref) async {
  return ref.watch(ordersApiProvider).orders();
});

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  bool _busy = false;

  Future<void> _move(VendorOrder order, String to) async {
    setState(() => _busy = true);
    try {
      await ref.read(ordersApiProvider).transition(id: order.id, to: to);
      ref.invalidate(ordersProvider);
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
    final orders = ref.watch(ordersProvider);

    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(apiMessage(e)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(ordersProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (rows) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(ordersProvider),
        child: rows.isEmpty
            ? const EmptyState(
                message: 'No orders yet. New orders pop up here.',
                icon: Icons.receipt_long_outlined,
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final order in rows)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${order.number} · ${order.customer}',
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w700),
                                  ),
                                ),
                                StatusChip(status: order.status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total ${order.total.toStringAsFixed(2)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                            ),
                            if (order.status == 'placed') ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.tonal(
                                      onPressed: _busy
                                          ? null
                                          : () => _move(
                                              order, 'accepted'),
                                      child:
                                          const Text('Accept'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton
                                          .styleFrom(
                                              foregroundColor:
                                                  Colors.red),
                                      onPressed: _busy
                                          ? null
                                          : () => _move(
                                              order, 'cancelled'),
                                      child:
                                          const Text('Cancel'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
