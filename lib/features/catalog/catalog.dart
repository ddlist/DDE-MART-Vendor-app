// DDE-Mart vendor app — stores + products toggles (original).
//
// GET /vendor/stores (open/close via POST toggle {is_open}),
// GET /vendor/products (q filter) + POST toggle active flag.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/nav.dart';
import '../../core/widgets.dart';

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

double _listPrice(Map<String, dynamic> product) =>
    ((product['price'] as num?) ?? 0).toDouble();

/// Effective price: discount wins only when positive and lower (a zero
/// discount_price means "no discount", never free).
double _salePrice(Map<String, dynamic> product) {
  final list = _listPrice(product);
  final discount = ((product['discount_price'] as num?) ?? 0).toDouble();
  if (discount > 0 && discount < list) return discount;
  return list;
}

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
          SectionHeader(
            title: 'Stores',
            onSeeAll: null,
          ),
          stores.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(apiMessage(e)),
            data: (rows) {
              if (rows.isEmpty) {
                return const EmptyState(
                  message: 'No stores assigned to you yet.',
                  icon: Icons.storefront_outlined,
                );
              }
              return Column(
                children: [
                  for (final store in rows)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ApiImage(
                              path: store['image'] as String?,
                              height: 56,
                              width: 56,
                              borderRadius:
                                  BorderRadius.circular(12),
                              icon: Icons.storefront_outlined,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('${store['name']}',
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  StatusChip(
                                      status: (store['is_open'] ??
                                                  false) ==
                                              true
                                          ? 'open'
                                          : 'closed'),
                                ],
                              ),
                            ),
                            Switch(
                              value: (store['is_open'] ??
                                      false) ==
                                  true,
                              onChanged: (value) async {
                                await guard(
                                  () => ref
                                      .read(catalogApiProvider)
                                      .setOpen(
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
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Products', style: Theme.of(context).textTheme.titleMedium),
              FilledButton.tonal(
                onPressed: () => context.safePush('/catalog/new'),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(apiMessage(e)),
            data: (rows) {
              if (rows.isEmpty) {
                return const EmptyState(
                  message: 'No products yet. Add your first item.',
                  icon: Icons.fastfood_outlined,
                );
              }
              return Column(
                children: [
                  for (final product in rows)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            ApiImage(
                              path:
                                  product['image'] as String?,
                              height: 64,
                              width: 64,
                              borderRadius:
                                  BorderRadius.circular(12),
                              icon: Icons.fastfood_outlined,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (product['veg']
                                          is bool) ...[
                                        VegMark(
                                            veg: product['veg']
                                                as bool),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(
                                        child: Text(
                                          '${product['name']}',
                                          maxLines: 1,
                                          overflow: TextOverflow
                                              .ellipsis,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  PriceText(
                                    price: _salePrice(product),
                                    was: _listPrice(product) >
                                            _salePrice(product)
                                        ? _listPrice(product)
                                        : null,
                                  ),
                                  const SizedBox(height: 2),
                                  StarsRow(
                                    avg: (product['rating_avg']
                                            as num?)
                                        ?.toDouble(),
                                    count: (product[
                                                'rating_count']
                                            as num?)
                                        ?.toInt(),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                      Icons.edit_outlined),
                                  tooltip: 'Edit',
                                  onPressed: () =>
                                      context.safePush(
                                    '/catalog/product/${product['id']}',
                                    extra: product,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.star_outline),
                                  tooltip: 'View ratings',
                                  onPressed: () =>
                                      context.safePush(
                                    '/product/${product['id']}/reviews',
                                  ),
                                ),
                                Switch(
                                  value: (product['is_active'] ??
                                          false) ==
                                      true,
                                  onChanged: (_) async {
                                    await guard(
                                      () => ref
                                          .read(
                                              catalogApiProvider)
                                          .toggleProduct(
                                            product['id']
                                                as int,
                                          ),
                                    );
                                    ref.invalidate(
                                        productsProvider);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
