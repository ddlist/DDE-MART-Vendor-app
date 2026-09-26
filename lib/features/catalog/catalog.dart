// DDE-Mart vendor app — stores + products toggles (original).
//
// GET /vendor/stores (open/close via POST toggle {is_open}),
// GET /vendor/products (q filter) + POST toggle active flag.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';

class CatalogApi {
  CatalogApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> stores() async {
    final response = await _dio.get('/vendor/stores');
    return (((response.data as Map)['data'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> setOpen({required int id, required bool open}) async {
    await _dio.post('/vendor/stores/$id/toggle', data: {'is_open': open});
  }

  Future<List<Map<String, dynamic>>> products() async {
    final response = await _dio.get('/vendor/products');
    return (((response.data as Map)['data'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> toggleProduct(int id) async {
    await _dio.post('/vendor/products/$id/toggle');
  }

  /// Create keeps one multipart shape (image optional). Numbers/bools ride
  /// as form fields; Laravel validates numeric strings fine.
  Future<Map<String, dynamic>> createProduct({
    required int storeId,
    required String name,
    String? description,
    required double price,
    double? discountPrice,
    int? quantity,
    XFile? image,
  }) async {
    final response = await _dio.post(
      '/vendor/products',
      data: _form({
        'store_id': storeId,
        'name': name,
        'description': description,
        'price': price,
        'discount_price': discountPrice,
        'quantity': quantity,
        'image': image == null
            ? null
            : await MultipartFile.fromFile(image.path, filename: image.name),
      }),
    );
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }

  /// Update via POST + _method spoof (multipart PUT bodies don't parse in PHP).
  Future<void> updateProduct({
    required int id,
    String? name,
    String? description,
    double? price,
    double? discountPrice,
    int? quantity,
    XFile? image,
    bool removeImage = false,
  }) async {
    await _dio.post(
      '/vendor/products/$id',
      data: _form({
        '_method': 'PUT',
        'name': name,
        'description': description,
        'price': price,
        'discount_price': discountPrice,
        'quantity': quantity,
        'remove_image': removeImage ? '1' : null,
        'image': image == null
            ? null
            : await MultipartFile.fromFile(image.path, filename: image.name),
      }),
    );
  }
}

/// Multipart body without null/blank fields.
FormData _form(Map<String, dynamic> fields) {
  fields.removeWhere((key, value) => value == null || value == '');
  return FormData.fromMap(fields);
}

final catalogApiProvider = Provider<CatalogApi>(
  (ref) => CatalogApi(ref.watch(dioProvider)),
);

final storesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(catalogApiProvider).stores();
});

final productsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(catalogApiProvider).products();
});

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(storesProvider);
    final products = ref.watch(productsProvider);
    Future<void> guard(Future<void> Function() call) async {
      try {
        await call();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(apiMessage(e))),
          );
        }
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(storesProvider);
        ref.invalidate(productsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Stores', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          stores.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(apiMessage(e)),
            data: (rows) => Column(
              children: [
                if (rows.isEmpty) const Text('No stores assigned.'),
                for (final store in rows)
                  SwitchListTile(
                    title: Text('${store['name']}'),
                    subtitle: Text('${store['status'] ?? ''}'),
                    value: (store['is_open'] ?? false) == true,
                    onChanged: (value) async {
                      await guard(
                        () => ref.read(catalogApiProvider).setOpen(
                              id: store['id'] as int,
                              open: value,
                            ),
                      );
                      ref.invalidate(storesProvider);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Products', style: Theme.of(context).textTheme.titleMedium),
              FilledButton.tonal(
                onPressed: () => context.push('/catalog/new'),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(apiMessage(e)),
            data: (rows) => Column(
              children: [
                if (rows.isEmpty) const Text('No products.'),
                for (final product in rows)
                  SwitchListTile(
                    title: Text('${product['name']}'),
                    subtitle: Text(
                      '${product['price']} · tap to edit',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: (product['is_active'] ?? false) == true,
                    onChanged: (_) async {
                      await guard(
                        () => ref.read(catalogApiProvider).toggleProduct(
                              product['id'] as int,
                            ),
                      );
                      ref.invalidate(productsProvider);
                    },
                    secondary: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => context.push(
                        '/catalog/product/${product['id']}',
                        extra: product,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
