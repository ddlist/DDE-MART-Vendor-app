// DDE-Mart vendor app — support chat inbox + subscription (original).
//
// Threads linked to owned stores (customer opened from an order number),
// with reply. Subscription shows plans + current subscription (purchase
// stays panel-side). Matches /vendor/chat/* and /vendor/subscription.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';

Map<String, dynamic> _item(Map e) => Map<String, dynamic>.from(e);

List<Map<String, dynamic>> _list(Object? data) =>
    ((data as List?) ?? []).map((e) => _item(e as Map)).toList();

class VendorChatApi {
  VendorChatApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> threads() async {
    final r = await _dio.get('/vendor/chat/threads');
    return _list((r.data as Map)['data']);
  }

  Future<Map<String, dynamic>> thread(int id) async {
    final r = await _dio.get('/vendor/chat/threads/$id');
    return _item((r.data as Map)['data'] as Map);
  }

  Future<void> reply({required int threadId, required String message}) async {
    await _dio.post('/vendor/chat/threads/$threadId/reply', data: {
      'message': message,
    });
  }

  Future<Map<String, dynamic>> subscription() async {
    final r = await _dio.get('/vendor/subscription');
    return _item((r.data as Map)['data'] as Map);
  }
}

final vendorChatApiProvider = Provider<VendorChatApi>(
  (ref) => VendorChatApi(ref.watch(dioProvider)),
);

void _fail(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(apiMessage(e))),
  );
}

class VendorChatThreadsScreen extends ConsumerWidget {
  const VendorChatThreadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(vendorChatApiProvider).threads(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('No customer messages.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['subject'] ?? 'Conversation'}'),
                    subtitle: Text('${row['last_message'] ?? ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/chat/${row['id']}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class VendorChatThreadScreen extends ConsumerStatefulWidget {
  const VendorChatThreadScreen({super.key, required this.threadId});

  final int threadId;

  @override
  ConsumerState<VendorChatThreadScreen> createState() =>
      _VendorChatThreadScreenState();
}

class _VendorChatThreadScreenState
    extends ConsumerState<VendorChatThreadScreen> {
  final _message = TextEditingController();
  Map<String, dynamic>? _thread;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _thread = await ref.read(vendorChatApiProvider).thread(widget.threadId);
    } catch (e) {
      if (mounted) _fail(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref.read(vendorChatApiProvider).reply(
            threadId: widget.threadId,
            message: text,
          );
      _message.clear();
      await _load();
    } catch (e) {
      if (mounted) _fail(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _thread == null ? [] : _list(_thread!['messages']);

    return Scaffold(
      appBar: AppBar(title: Text('${_thread?['subject'] ?? 'Conversation'}')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(child: Text('No messages yet.'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final message in messages)
                            Align(
                              alignment: (message['from_me'] ?? false) == true
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Card(
                                color: (message['from_me'] ?? false) == true
                                    ? Colors.purple.shade100
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text('${message['body']}'),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    decoration: const InputDecoration(labelText: 'Reply'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _busy ? null : _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.watch(vendorChatApiProvider).subscription(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final data = snapshot.data!;
          final mine = data['mine'];
          final plans = _list(data['plans']);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text(
                    mine == null
                        ? 'No active subscription'
                        : '${(mine as Map)['plan']?['name'] ?? 'Plan'}',
                  ),
                  subtitle: mine == null
                      ? const Text('Subscribe from the admin panel.')
                      : Text(
                          (mine['expired'] ?? false) == true
                              ? 'Expired'
                              : 'Valid until ${mine['ends_at'] ?? '—'}',
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Plans', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final plan in plans)
                Card(
                  child: ListTile(
                    title: Text('${plan['name']}'),
                    subtitle: Text(
                      '${plan['price']} · ${plan['validity_days'] ?? '—'} days',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
