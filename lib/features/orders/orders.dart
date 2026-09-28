// DDE-Mart vendor app — orders inbox.
//
// GET /vendor/orders (own stores) + POST /vendor/orders/{id}/transition
// {to: accepted|cancelled}. Placed orders show both actions. A compact
// public stories strip (GET /stories) sits above the inbox tabs.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/nav.dart';
import '../../core/widgets.dart';
import '../stories/stories.dart';

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

  Future<List<VendorOrder>> orders({String? status}) async {
    final response = await _dio.get('/vendor/orders',
        queryParameters: {'status': ?status});
    final data = ((response.data as Map)['data'] as List?) ?? [];
    return data
        .map((e) => VendorOrder.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> order(int id) async {
    final response = await _dio.get('/vendor/orders/$id');
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }

  Future<void> transition({required int id, required String to}) async {
    await _dio.post('/vendor/orders/$id/transition', data: {'to': to});
  }
}

final ordersApiProvider = Provider<OrdersApi>(
  (ref) => OrdersApi(ref.watch(dioProvider)),
);

final ordersFilterProvider = StateProvider<String?>((ref) => null);

final ordersProvider = FutureProvider<List<VendorOrder>>((ref) async {
  return ref.watch(ordersApiProvider).orders(status: ref.watch(ordersFilterProvider));
});

final vendorOrderProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  return ref.watch(ordersApiProvider).order(id);
});

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

const _orderTabs = <String?>[null, 'placed', 'accepted', 'completed', 'cancelled'];

String _tabLabel(String? status) {
  return switch (status) {
    null => 'All',
    'placed' => 'New',
    'accepted' => 'Accepted',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    _ => status,
  };
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
    final filter = ref.watch(ordersFilterProvider);
    final orders = ref.watch(ordersProvider);
    final stories = ref.watch(storiesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GradientHeader(
            title: 'Orders inbox',
            subtitle: 'Accept new orders, track them to completion.',
            icon: Icons.receipt_long_outlined,
          ),
        ),
        stories.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (rows) => rows.isEmpty
              ? const SizedBox.shrink()
              : StoryStrip(stories: [for (final s in rows) s.toJson()]),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              for (final tab in _orderTabs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_tabLabel(tab)),
                    selected: filter == tab,
                    onSelected: (_) =>
                        ref.read(ordersFilterProvider.notifier).state = tab,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: orders.when(
      loading: () => const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: ShimmerList(rows: 4),
      ),
      error: (e, _) => ErrorRetry(
        error: e,
        onRetry: () => ref.invalidate(ordersProvider),
      ),
      data: (rows) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ordersProvider);
          ref.invalidate(storiesProvider);
        },
        child: rows.isEmpty
            ? const EmptyState(
                message: 'No orders yet. New orders pop up here.',
                icon: Icons.receipt_long_outlined,
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final order in rows)
                    SleekCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${order.number} · ${order.customer}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              StatusChip(status: order.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          PriceText(price: order.total),
                          if (order.status == 'placed') ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.tonal(
                                    onPressed: _busy
                                        ? null
                                        : () => _move(order, 'accepted'),
                                    child: const Text('Accept'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Theme.of(context)
                                            .colorScheme
                                            .error),
                                    onPressed: _busy
                                        ? null
                                        : () => _move(order, 'cancelled'),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context
                                  .safePush('/order/${order.id}'),
                              child: const Text('View details'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
          )),
        ],
      );
  }
}

class VendorOrderDetailScreen extends ConsumerStatefulWidget {
  const VendorOrderDetailScreen(
      {super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<VendorOrderDetailScreen> createState() =>
      _VendorOrderDetailScreenState();
}

class _VendorOrderDetailScreenState
    extends ConsumerState<VendorOrderDetailScreen> {
  bool _busy = false;

  Future<void> _move(String to) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(ordersApiProvider)
          .transition(id: widget.orderId, to: to);
      ref.invalidate(vendorOrderProvider(widget.orderId));
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
    final order = ref.watch(vendorOrderProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: order.when(
        loading: () => const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: ShimmerList(rows: 3),
        ),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(vendorOrderProvider(widget.orderId)),
        ),
        data: (data) {
          final items = ((data['items'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final timeline = ((data['timeline'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final status = '${data['status']}';

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(vendorOrderProvider(widget.orderId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GradientHeader(
                  title: '${data['number'] ?? 'Order #${data['id']}'}',
                  subtitle: '${data['customer_name'] ?? ''}'
                      '${data['customer_phone'] != null ? ' · ${data['customer_phone']}' : ''}',
                  icon: Icons.receipt_long_outlined,
                  action: StatusChip(status: status),
                ),
                const SizedBox(height: 12),
                if (data['address'] != null &&
                    '${data['address']}'.isNotEmpty)
                  SleekCard(
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${data['address']}')),
                      ],
                    ),
                  ),
                if (data['address'] != null &&
                    '${data['address']}'.isNotEmpty)
                  const SizedBox(height: 12),
                if (data['notes'] != null &&
                    '${data['notes']}'.isNotEmpty)
                  SleekCard(
                    child: Text(
                      'Note: ${data['notes']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (data['notes'] != null &&
                    '${data['notes']}'.isNotEmpty)
                  const SizedBox(height: 12),
                SleekCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Items',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                    '${item['name']} × ${item['quantity']}'),
                              ),
                              Text(
                                '${item['subtotal'] ?? ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      const Divider(),
                      BillRow(
                        label: 'Subtotal',
                        value: '${data['subtotal'] ?? '—'}',
                      ),
                      BillRow(
                        label: 'Discount',
                        value: '${data['discount'] ?? '—'}',
                      ),
                      BillRow(
                        label: 'Delivery',
                        value: '${data['delivery_charge'] ?? '—'}',
                      ),
                      BillRow(label: 'Tax', value: '${data['tax'] ?? '—'}'),
                      const SizedBox(height: 4),
                      BillRow(
                        label: 'Total',
                        value: '${data['total'] ?? '—'}',
                        strong: true,
                      ),
                    ],
                  ),
                ),
                if (timeline.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SleekCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Timeline',
                            style:
                                Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TimelineDots(
                          entries: [
                            for (final entry in timeline)
                              TimelineEntry(
                                title: '${entry['to'] ?? ''}',
                                subtitle: entry['at'] == null
                                    ? null
                                    : '${entry['at']}',
                                color: StatusChip.colorFor(
                                    '${entry['to'] ?? ''}'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (status == 'placed') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _busy
                              ? null
                              : () => _move('accepted'),
                          child: const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error),
                          onPressed: _busy
                              ? null
                              : () => _move('cancelled'),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}
