// DDE-Mart vendor app — coupons (original).
//
// GET /vendor/coupons (own stores), POST /vendor/coupons (store-bound,
// code uppercased server-side), PUT /vendor/coupons/{id} (tune + toggle).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../catalog/catalog.dart';

Map<String, dynamic> _item(Map e) => Map<String, dynamic>.from(e);

List<Map<String, dynamic>> _list(Object? data) =>
    ((data as List?) ?? []).map((e) => _item(e as Map)).toList();

class CouponsApi {
  CouponsApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> coupons() async {
    final r = await _dio.get('/vendor/coupons');
    return _list((r.data as Map)['data']);
  }

  Future<void> create({
    required int storeId,
    required String code,
    required String discountType,
    required double discountValue,
    double? minOrder,
    int? usageLimit,
  }) async {
    final data = <String, Object>{
      'store_id': storeId,
      'code': code,
      'discount_type': discountType,
      'discount_value': discountValue,
    };
    if (minOrder != null) data['min_order'] = minOrder;
    if (usageLimit != null) data['usage_limit'] = usageLimit;
    await _dio.post('/vendor/coupons', data: data);
  }

  Future<void> update({required int id, required Map<String, Object> fields}) async {
    await _dio.put('/vendor/coupons/$id', data: fields);
  }
}

final couponsApiProvider = Provider<CouponsApi>(
  (ref) => CouponsApi(ref.watch(dioProvider)),
);

final couponsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(couponsApiProvider).coupons();
});

class CouponsScreen extends ConsumerWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupons = ref.watch(couponsProvider);

    return Scaffold(
      body: coupons.when(
        loading: () => const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: ShimmerList(rows: 3),
        ),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(couponsProvider),
        ),
        data: (rows) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(couponsProvider),
          child: rows.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GradientHeader(
                      title: 'Coupons',
                      subtitle: 'Discounts funded by your stores.',
                      icon: Icons.local_offer_outlined,
                      action: _NewCouponButton(
                        onTap: () => context.safePush('/coupons/new'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const EmptyState(
                      message: 'No coupons yet. Create one with +.',
                      icon: Icons.local_offer_outlined,
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GradientHeader(
                      title: 'Coupons',
                      subtitle: 'Discounts funded by your stores.',
                      icon: Icons.local_offer_outlined,
                      action: _NewCouponButton(
                        onTap: () => context.safePush('/coupons/new'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final row in rows)
                      SleekCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${row['code']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                StatusChip(
                                    status: (row['is_active'] ?? false) ==
                                            true
                                        ? 'active'
                                        : 'paused'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${row['discount_type']} ${row['discount_value']} · '
                              'used ${row['used_count'] ?? 0}/${row['usage_limit'] ?? '∞'}',
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enabled'),
                              value:
                                  (row['is_active'] ?? false) == true,
                              onChanged: (value) async {
                                final messenger =
                                    ScaffoldMessenger.of(context);
                                try {
                                  await ref
                                      .read(couponsApiProvider)
                                      .update(
                                        id: row['id'] as int,
                                        fields: {'is_active': value},
                                      );
                                  ref.invalidate(couponsProvider);
                                } catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                        content:
                                            Text(apiMessage(e))),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// White-on-hero "+ New" action used by the coupons header.
class _NewCouponButton extends StatelessWidget {
  const _NewCouponButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: DdeVendorTheme.primaryDeep,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      onPressed: onTap,
      child: const Text('+ New'),
    );
  }
}

const _couponTypes = ['percentage', 'fixed'];

class CouponEditorScreen extends ConsumerStatefulWidget {
  const CouponEditorScreen({super.key});

  @override
  ConsumerState<CouponEditorScreen> createState() => _CouponEditorScreenState();
}

class _CouponEditorScreenState extends ConsumerState<CouponEditorScreen> {
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _minOrder = TextEditingController();
  final _usageLimit = TextEditingController();
  String _type = _couponTypes.first;
  int? _storeId;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _minOrder.dispose();
    _usageLimit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stores = ref.watch(storesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New coupon')),
      body: stores.when(
        loading: () => const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: ShimmerList(rows: 3),
        ),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(storesProvider),
        ),
        data: (rows) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const GradientHeader(
              title: 'New coupon',
              subtitle: 'Fund a discount from one of your stores.',
              icon: Icons.local_offer_outlined,
            ),
            const SizedBox(height: 12),
            SleekCard(
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue:
                        _storeId ?? (rows.firstOrNull?['id'] as int?),
                    items: [
                      for (final store in rows)
                        DropdownMenuItem(
                          value: store['id'] as int,
                          child: Text('${store['name']}'),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _storeId = value),
                    decoration: const InputDecoration(
                        labelText: 'Store (funds the discount)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Code (e.g. FLAT50)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    items: [
                      for (final t in _couponTypes)
                        DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged: (value) =>
                        setState(() => _type = value ?? _couponTypes.first),
                    decoration:
                        const InputDecoration(labelText: 'Type'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _value,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Value (% or amount)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _minOrder,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Min order (optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usageLimit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Usage limit (optional)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final storeId = _storeId ?? rows.firstOrNull?['id'] as int?;
                      final value = double.tryParse(_value.text.trim()) ?? -1;
                      if (storeId == null || _code.text.trim().isEmpty || value < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Store, code and value are required.')),
                        );
                        return;
                      }
                      setState(() => _busy = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      try {
                        await ref.read(couponsApiProvider).create(
                              storeId: storeId,
                              code: _code.text.trim(),
                              discountType: _type,
                              discountValue: value,
                              minOrder: double.tryParse(_minOrder.text.trim()),
                              usageLimit: int.tryParse(_usageLimit.text.trim()),
                            );
                        ref.invalidate(couponsProvider);
                        navigator.pop();
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(apiMessage(e))),
                        );
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: Text(_busy ? 'Creating…' : 'Create coupon'),
            ),
          ],
        ),
      ),
    );
  }
}
