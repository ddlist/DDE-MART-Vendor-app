// DDE-Mart vendor app — product editor (original).
//
// Create inside an owned store, or edit an owned product. Photo optional
// (gallery picker → multipart). Mirrors POST|PUT /vendor/products*.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import 'catalog.dart';

class ProductEditorScreen extends ConsumerStatefulWidget {
  const ProductEditorScreen({super.key, this.product, this.storeId});

  /// Null = create mode (storeId required). Set = edit mode.
  final Map<String, dynamic>? product;
  final int? storeId;

  @override
  ConsumerState<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends ConsumerState<ProductEditorScreen> {
  late final _name = TextEditingController(text: '${widget.product?['name'] ?? ''}');
  late final _description =
      TextEditingController(text: '${widget.product?['description'] ?? ''}');
  late final _price =
      TextEditingController(text: '${widget.product?['price'] ?? ''}');
  late final _discount =
      TextEditingController(text: '${widget.product?['discount_price'] ?? ''}');
  late final _quantity =
      TextEditingController(text: '${widget.product?['quantity'] ?? ''}');
  int? _storeId;
  XFile? _image;
  bool _busy = false;

  bool get _create => widget.product == null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _discount.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save(List<Map<String, dynamic>> stores) async {
    final storeId = _create ? (_storeId ?? stores.firstOrNull?['id'] as int?) : null;
    if (_create && storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a store first.')),
      );
      return;
    }

    final price = double.tryParse(_price.text.trim()) ?? -1;
    if (_name.text.trim().isEmpty || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and a valid price are required.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final api = ref.read(catalogApiProvider);
      if (_create) {
        await api.createProduct(
          storeId: storeId!,
          name: _name.text.trim(),
          description: _description.text.trim(),
          price: price,
          discountPrice: double.tryParse(_discount.text.trim()),
          quantity: int.tryParse(_quantity.text.trim()),
          image: _image,
        );
      } else {
        await api.updateProduct(
          id: widget.product!['id'] as int,
          name: _name.text.trim(),
          description: _description.text.trim(),
          price: price,
          discountPrice: double.tryParse(_discount.text.trim()),
          quantity: int.tryParse(_quantity.text.trim()),
          image: _image,
        );
      }
      ref.invalidate(storesProvider);
      ref.invalidate(productsProvider);
      if (mounted) context.pop();
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
    final stores = ref.watch(storesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_create ? 'New product' : 'Edit product')),
      body: stores.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiMessage(e))),
        data: (rows) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_create)
              DropdownButtonFormField<int>(
                initialValue: _storeId ?? (rows.firstOrNull?['id'] as int?),
                items: [
                  for (final store in rows)
                    DropdownMenuItem(
                      value: store['id'] as int,
                      child: Text('${store['name']}'),
                    ),
                ],
                onChanged: (value) => setState(() => _storeId = value),
                decoration: const InputDecoration(labelText: 'Store'),
              ),
            if (_create) const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _discount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Discount (optional)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock (optional)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_outlined),
              label: Text(_image == null ? 'Add photo (optional)' : _image!.name),
              onPressed: _busy
                  ? null
                  : () async {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                      );
                      if (picked != null) setState(() => _image = picked);
                    },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : () => _save(rows),
              child: Text(_busy ? 'Saving…' : (_create ? 'Create product' : 'Save changes')),
            ),
          ],
        ),
      ),
    );
  }
}
