// DDE-Mart vendor app — support chat inbox + subscription (original).
//
// Threads linked to owned stores (customer opened from an order number),
// with reply. Subscription shows plans + current subscription (purchase
// stays panel-side). Matches /vendor/chat/* and /vendor/subscription.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../core/nav.dart';

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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(vendorChatApiProvider).threads(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: ShimmerList(rows: 4, height: 72),
            );
          }
          if (snapshot.hasError) {
            return ErrorRetry(
              error: snapshot.error!,
              onRetry: () => (context as Element).markNeedsBuild(),
            );
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                GradientHeader(
                  title: 'Messages',
                  subtitle: 'Customer conversations.',
                  icon: Icons.chat_outlined,
                ),
                SizedBox(height: 24),
                EmptyState(
                  message: 'No customer messages yet.',
                  icon: Icons.chat_outlined,
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const GradientHeader(
                title: 'Messages',
                subtitle: 'Customer conversations.',
                icon: Icons.chat_outlined,
              ),
              const SizedBox(height: 12),
              for (final row in rows)
                SleekCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.zero,
                  onTap: () => context.safePush('/chat/${row['id']}'),
                  child: ListTile(
                    title:
                        Text('${row['subject'] ?? 'Conversation'}'),
                    subtitle: Text('${row['last_message'] ?? ''}'),
                    trailing: const Icon(Icons.chevron_right),
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
                ? const SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: ShimmerList(rows: 4, height: 64),
                  )
                : messages.isEmpty
                    ? const EmptyState(
                        message: 'No messages yet.',
                        icon: Icons.chat_outlined,
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final message in messages)
                            Align(
                              alignment: (message['from_me'] ?? false) == true
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: (message['from_me'] ?? false) ==
                                          true
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Text(
                                  '${message['body']}',
                                  style: TextStyle(
                                    color: (message['from_me'] ??
                                                false) ==
                                            true
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                        : null,
                                  ),
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.watch(vendorChatApiProvider).subscription(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: ShimmerList(rows: 3),
            );
          }
          if (snapshot.hasError) {
            return ErrorRetry(
              error: snapshot.error!,
              onRetry: () => (context as Element).markNeedsBuild(),
            );
          }
          final data = snapshot.data!;
          final mine = data['mine'];
          final plans = _list(data['plans']);

          final currentPlan = mine == null
              ? null
              : (mine as Map)['plan']?['name'];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GradientHeader(
                title: 'Subscription',
                subtitle: mine == null
                    ? 'Subscribe from the admin panel.'
                    : '${(mine as Map)['plan']?['name'] ?? 'Plan'}',
                icon: Icons.workspace_premium_outlined,
                action: StatusChip(
                    status: mine == null
                        ? 'none'
                        : ((mine['expired'] ?? false) == true
                            ? 'expired'
                            : 'active')),
              ),
              const SizedBox(height: 12),
              SleekCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient:
                            DdeVendorTheme.accentGradient(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mine == null
                                ? 'No active subscription'
                                : '${(mine as Map)['plan']?['name'] ?? 'Plan'}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                          Text(
                            mine == null
                                ? 'Subscribe from the admin panel.'
                                : ((mine['expired'] ?? false) == true
                                    ? 'Expired'
                                    : 'Valid until ${mine['ends_at'] ?? '—'}'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Available plans',
                  style:
                      Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final plan in plans)
                SleekCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('${plan['name']}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium),
                          ),
                          if ('${plan['name']}' == currentPlan)
                            const StatusChip(status: 'current'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${plan['price']} · ${plan['validity_days'] ?? '—'} days',
                        style:
                            Theme.of(context).textTheme.bodySmall,
                      ),
                      for (final feature
                          in ((plan['features'] as List?) ?? []))
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.check,
                                  size: 16, color: Colors.green),
                              const SizedBox(width: 6),
                              Expanded(child: Text('$feature')),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
