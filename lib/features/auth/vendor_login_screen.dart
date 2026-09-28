// DDE-Mart vendor app — OTP sign-in screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import '../../core/widgets.dart';
import 'vendor_auth_api.dart';

class VendorLoginScreen extends ConsumerStatefulWidget {
  const VendorLoginScreen({super.key});

  @override
  ConsumerState<VendorLoginScreen> createState() => _VendorLoginScreenState();
}

class _VendorLoginScreenState extends ConsumerState<VendorLoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String _role = 'vendor';
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _fail(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(apiMessage(e))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            const GradientHeader(
              title: 'Vendor sign in',
              subtitle: 'Store owners sign in with a code.',
              icon: Icons.storefront_outlined,
            ),
            const SizedBox(height: 16),
            SleekCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'vendor', label: Text('Vendor')),
                      ButtonSegment(value: 'owner', label: Text('Owner')),
                    ],
                    selected: {_role},
                    onSelectionChanged: (values) =>
                        setState(() => _role = values.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              final debug = await ref
                                  .read(vendorAuthApiProvider)
                                  .otpRequest(
                                      phone: _phone.text.trim(), role: _role);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      debug == null
                                          ? 'Code sent.'
                                          : 'Code sent (debug: $debug).',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) _fail(e);
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: const Text('Send code'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SleekCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: '6-digit code'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              final payload = await ref
                                  .read(vendorAuthApiProvider)
                                  .otpVerify(
                                    phone: _phone.text.trim(),
                                    role: _role,
                                    code: _code.text.trim(),
                                  );
                              await ref
                                  .read(authStoreProvider.notifier)
                                  .signIn(
                                    token: '${payload['token']}',
                                    name: '${payload['name'] ?? ''}',
                                    phone: _phone.text.trim(),
                                  );
                              if (context.mounted) context.go('/orders');
                            } catch (e) {
                              if (context.mounted) _fail(e);
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: const Text('Verify & sign in'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
