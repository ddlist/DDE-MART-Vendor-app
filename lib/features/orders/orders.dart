// DDE-Mart vendor app — orders inbox (original).
//
// GET /vendor/orders (own stores) + POST /vendor/orders/{id}/transition
// {to: accepted|cancelled}. Placed orders show both actions.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (rows.isEmpty) const Text('No orders yet.'),
            for (final order in rows)
              Card(
                child: ListTile(
                  title: Text('${order.number} · ${order.customer}'),
                  subtitle: Text('${order.status} · ${order.total.toStringAsFixed(2)}'),
                  trailing: order.status == 'placed' && !_busy
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              tooltip: 'Accept',
                              onPressed: () => _move(order, 'accepted'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Cancel',
                              onPressed: () => _move(order, 'cancelled'),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
