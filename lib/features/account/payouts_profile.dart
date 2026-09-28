// DDE-Mart vendor app — payouts + profile.
//
// GET /vendor/payouts + POST /vendor/payouts {amount, method}; profile with
// sign out via POST /vendor/logout. The edit screen offers an avatar upload
// (POST /vendor/uploads) with preview — PUT /vendor/profile accepts name +
// email only, so the avatar is preview-only until the backend stores one.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import '../../core/nav.dart';
import '../../core/permissions.dart';
import '../../core/push.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
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
        const GradientHeader(
          title: 'Payouts',
          subtitle: 'Withdraw earnings to your account.',
          icon: Icons.payments_outlined,
        ),
        const SizedBox(height: 12),
        SleekCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Request payout',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _method,
                items: [
                  for (final m in _methods)
                    DropdownMenuItem(value: m, child: Text(m))
                ],
                onChanged: (value) =>
                    setState(() => _method = value ?? _methods.first),
                decoration: const InputDecoration(labelText: 'Method'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final amount =
                            double.tryParse(_amount.text.trim()) ?? 0;
                        if (amount < 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Enter an amount of at least 1.')),
                          );
                          return;
                        }
                        setState(() => _busy = true);
                        try {
                          await ref
                              .read(vendorPayoutsApiProvider)
                              .request(
                                amount: amount,
                                method: _method,
                              );
                          ref.invalidate(vendorPayoutsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Payout requested.')),
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('History', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        payouts.when(
          loading: () => const ShimmerList(rows: 3, height: 72),
          error: (e, _) => ErrorRetry(
            error: e,
            onRetry: () => ref.invalidate(vendorPayoutsProvider),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const EmptyState(
                message: 'No payouts yet. Request one above.',
                icon: Icons.payments_outlined,
              );
            }
            return Column(
              children: [
                for (final row in rows)
                  SleekCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_outlined),
                      title:
                          Text('${row['amount']} · ${row['method'] ?? ''}'),
                      subtitle: row['created_at'] == null
                          ? null
                          : Text('${row['created_at']}'),
                      trailing:
                          StatusChip(status: '${row['status'] ?? ''}'),
                    ),
                  ),
              ],
            );
          },
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
    final themeMode = ref.watch(themeModeProvider);

    return FutureBuilder<Map<String, dynamic>>(
      future: ref.watch(vendorAuthApiProvider).me(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: ShimmerList(rows: 4, height: 72),
          );
        }
        final me = snapshot.data;
        final name = '${me?['name'] ?? auth.name ?? 'Vendor'}';
        final initial =
            name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(apiMessage(snapshot.error!)),
              ),
            SleekCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          DdeVendorTheme.accentGradient(context),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          Theme.of(context).colorScheme.surface,
                      child: Text(initial,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge),
                        Text('${me?['phone'] ?? auth.phone ?? ''}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit profile',
                    onPressed: () =>
                        context.safePush('/profile/edit', extra: me),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ProfileTile(
              icon: Icons.receipt_long_outlined,
              title: 'Orders inbox',
              onTap: () => context.safePush('/orders'),
            ),
            _ProfileTile(
              icon: Icons.storefront_outlined,
              title: 'Catalog',
              onTap: () => context.safePush('/catalog'),
            ),
            _ProfileTile(
              icon: Icons.local_offer_outlined,
              title: 'Coupons',
              onTap: () => context.safePush('/coupons'),
            ),
            _ProfileTile(
              icon: Icons.workspace_premium_outlined,
              title: 'Subscription',
              onTap: () => context.safePush('/subscription'),
            ),
            _ProfileTile(
              icon: Icons.chat_outlined,
              title: 'Customer messages',
              onTap: () => context.safePush('/chat'),
            ),
            const SizedBox(height: 12),
            SleekCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Appearance',
                      style:
                          Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Auto')),
                      ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light')),
                      ButtonSegment(
                          value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (set) => ref
                        .read(themeModeProvider.notifier)
                        .set(set.first),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, false),
                        child: const Text('Stay'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (confirm != true || !context.mounted) return;
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
            const SizedBox(height: 16),
            const _VersionFooter(),
          ],
        );
      },
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SleekCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Edit owner name + email (phone is the identity and stays read-only),
/// plus an avatar upload row (POST /vendor/uploads with preview).
class VendorEditProfileScreen extends ConsumerStatefulWidget {
  const VendorEditProfileScreen({super.key, this.initial});

  final Map<String, dynamic>? initial;

  @override
  ConsumerState<VendorEditProfileScreen> createState() =>
      _VendorEditProfileScreenState();
}

class _VendorEditProfileScreenState
    extends ConsumerState<VendorEditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  bool _busy = false;
  bool _uploading = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _name =
        TextEditingController(text: '${widget.initial?['name'] ?? ''}');
    _email =
        TextEditingController(text: '${widget.initial?['email'] ?? ''}');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final allowed = await ref
        .read(permissionServiceProvider)
        .ensure(context, AppPermission.photos);
    if (!allowed || !mounted) return;
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final result =
          await ref.read(vendorAuthApiProvider).uploadFile(picked.path);
      if (mounted) {
        setState(() => _avatarUrl = result['url']);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your name.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(vendorAuthApiProvider).updateProfile(
            name: _name.text.trim(),
            email: _email.text.trim().isEmpty
                ? null
                : _email.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
        context.pop();
      }
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
    final initial =
        _name.text.trim().isEmpty ? '?' : _name.text.trim()[0].toUpperCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const GradientHeader(
            title: 'Edit profile',
            subtitle: 'Keep your name and email up to date.',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          SleekCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  backgroundImage:
                      _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl != null
                      ? null
                      : Text(initial,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile photo',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall),
                      Text(
                        'Uploads to your gallery.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _uploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton.icon(
                        onPressed: _busy ? null : _pickAvatar,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Upload'),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SleekCard(
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration:
                      const InputDecoration(labelText: 'Full name'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: 'Email'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save details'),
          ),
        ],
      ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '';
        return Center(
          child: Text(
            version.isEmpty ? '' : 'v$version',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}
