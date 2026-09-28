// DDE-Mart vendor app — public stories rail.
//
// GET /stories (public): active vendor stories, newest first, capped at 30
// server-side. Shape: {id, store: {id, name}, video_url, thumbnail}.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class VendorStory {
  VendorStory({
    required this.id,
    this.storeId,
    this.storeName,
    this.videoUrl,
    this.thumbnail,
  });

  factory VendorStory.fromJson(Map<String, dynamic> json) {
    final store = json['store'];
    return VendorStory(
      id: (json['id'] as num?)?.toInt() ?? 0,
      storeId: store is Map ? (store['id'] as num?)?.toInt() : null,
      storeName: store is Map ? '${store['name'] ?? ''}' : null,
      videoUrl: json['video_url'] as String?,
      thumbnail: json['thumbnail'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'store': {'id': storeId, 'name': storeName},
        'video_url': videoUrl,
        'thumbnail': thumbnail,
      };

  /// Stories without a link are display-only; tapping one with a link
  /// opens its preview.
  bool get hasLink => (videoUrl ?? '').isNotEmpty;

  final int id;
  final int? storeId;
  final String? storeName;
  final String? videoUrl;
  final String? thumbnail;
}

class StoriesApi {
  StoriesApi(this._dio);

  final Dio _dio;

  Future<List<VendorStory>> fetchStories() async {
    final response = await _dio.get('/stories');
    final data = ((response.data as Map)['data'] as List?) ?? [];
    return data
        .map((e) => VendorStory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

final storiesApiProvider = Provider<StoriesApi>(
  (ref) => StoriesApi(ref.watch(dioProvider)),
);

/// Public rail — failures resolve to an empty list so the orders inbox
/// never breaks when stories are down.
final storiesProvider = FutureProvider<List<VendorStory>>((ref) async {
  try {
    return await ref.watch(storiesApiProvider).fetchStories();
  } catch (_) {
    return [];
  }
});
