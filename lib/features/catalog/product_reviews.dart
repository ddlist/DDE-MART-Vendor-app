// DDE-Mart vendor app — product ratings (original).
//
// Read-only view of the public approved-review feed for one product, so
// vendors see exactly what customers see (stars, comments, authors).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';

class VendorReviewsApi {
  VendorReviewsApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> productReviews(int id) async {
    final r = await _dio.get('/products/$id/reviews');
    return (((r.data as Map)['data'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

final vendorReviewsApiProvider = Provider<VendorReviewsApi>(
  (ref) => VendorReviewsApi(ref.watch(dioProvider)),
);

class VendorProductReviewsScreen extends ConsumerWidget {
  const VendorProductReviewsScreen({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product reviews')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(vendorReviewsApiProvider).productReviews(productId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const EmptyState(
              message: 'No approved reviews yet.',
              icon: Icons.star_outline,
            );
          }
          final avg = rows.fold<double>(
                  0, (s, r) => s + ((r['rating'] as num?) ?? 0)) /
              rows.length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      StarsRow(avg: avg, count: rows.length),
                      const Spacer(),
                      Text('${avg.toStringAsFixed(1)} / 5',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final r in rows)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (var i = 1; i <= 5; i++)
                              Icon(
                                i <=
                                        ((r['rating'] as num?) ??
                                                0)
                                            .toInt()
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 16,
                                color: Colors.amber[700],
                              ),
                            const Spacer(),
                            Text(
                              '${r['author_name'] ?? 'Customer'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                            ),
                          ],
                        ),
                        if ('${r['comment'] ?? ''}'
                            .isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('${r['comment']}'),
                        ],
                      ],
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
