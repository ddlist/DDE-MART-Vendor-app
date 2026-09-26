// DDE-Mart vendor app — payouts + profile (original).
//
// GET /vendor/payouts + POST /vendor/payouts {amount, method}; profile with
// sign out via POST /vendor/logout.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import '../../core/push.dart';
import '../auth/vendor_auth_api.dart';

class VendorPayoutsApi {
  VendorPayoutsApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> list() async {
    final response = await _dio.get('/vendor/payouts');
    return (((response.data as Map)['data'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> request({required double amount, required String method}) async {
    await _dio.post('/vendor/payouts', data: {'amount': amount, 'method': method});
  }
}

final vendorPayoutsApiProvider = Provider<VendorPayoutsApi>(
  (ref) => VendorPayoutsApi(ref.watch(dioProvider)),
);

final vendorPayoutsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(vendorPayoutsApiProvider).list();
});

const _methods = ['bank', 'paypal', 'stripe', 'razorpay', 'flutterwave', 'cash'];

class VendorPayoutsScreen extends ConsumerStatefulWidget {
  const VendorPayoutsScreen({super.key});

  @override
  ConsumerState<VendorPayoutsScreen> createState() => _VendorPayoutsScreenState();
}

class _VendorPayoutsScreenState extends ConsumerState<VendorPayoutsScreen> {
  final _amount = TextEditingController();
  String _method = _methods.first;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payouts = ref.watch(vendorPayoutsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Request payout', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _method,
          items: [for (final m in _methods) DropdownMenuItem(value: m, child: Text(m))],
          onChanged: (value) => setState(() => _method = value ?? _methods.first),
          decoration: const InputDecoration(labelText: 'Method'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final amount = double.tryParse(_amount.text.trim()) ?? 0;
                  if (amount < 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter an amount of at least 1.')),
                    );
                    return;
                  }
                  setState(() => _busy = true);
                  try {
                    await ref.read(vendorPayoutsApiProvider).request(
                          amount: amount,
                          method: _method,
                        );
                    ref.invalidate(vendorPayoutsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payout requested.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(apiMessage(e))),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'Sending…' : 'Request'),
        ),
        const SizedBox(height: 16),
        Text('History', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        payouts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(apiMessage(e)),
          data: (rows) => Column(
            children: [
              if (rows.isEmpty) const Text('No payouts yet.'),
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['amount']} · ${row['method']}'),
                    trailing: Text('${row['status']}'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class VendorProfileScreen extends ConsumerWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStoreProvider);

    return FutureBuilder<Map<String, dynamic>>(
      future: ref.watch(vendorAuthApiProvider).me(),
      builder: (context, snapshot) {
        final me = snapshot.data;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${me?['name'] ?? auth.name ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (snapshot.hasError) Text(apiMessage(snapshot.error!)),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_offer_outlined),
                title: const Text('Coupons'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/coupons'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Subscription'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/subscription'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () async {
                try {
                  await ref.read(vendorAuthApiProvider).logout();
                } finally {
                  await ref.read(pushServiceProvider).unregister();
                  await ref.read(authStoreProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                }
              },
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );
  }
}
