// DDE-Mart vendor app — API parity tests (uploads + stories).
//
// Covers POST /vendor/uploads (multipart `file` field) and GET /stories
// (public) with a stubbed Dio, plus the StoryStrip rail widget.

import 'dart:io';

import 'package:dde_vendor/core/widgets.dart';
import 'package:dde_vendor/features/auth/vendor_auth_api.dart';
import 'package:dde_vendor/features/stories/stories.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Dio _stubDio({RequestOptions? Function(RequestOptions)? capture}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        capture?.call(options);
        if (options.path == '/vendor/uploads' && options.method == 'POST') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'data': {
                  'path': 'avatars/photo.jpg',
                  'url': 'http://10.0.2.2:8000/storage/avatars/photo.jpg',
                },
              },
            ),
          );
          return;
        }
        if (options.path == '/stories' && options.method == 'GET') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': [
                  {
                    'id': 3,
                    'store': {'id': 7, 'name': 'Spice Route'},
                    'video_url': 'https://cdn.example/s3.mp4',
                    'thumbnail': '/storage/thumbs/s3.jpg',
                  },
                  {
                    'id': 2,
                    'store': {'id': 9, 'name': 'Crumb House'},
                    'video_url': null,
                    'thumbnail': null,
                  },
                ],
              },
            ),
          );
          return;
        }
        handler.reject(
          DioException(requestOptions: options, error: 'unexpected call'),
        );
      },
    ),
  );
  return dio;
}

Future<String> _tempImage() async {
  final file = File(
      '${Directory.systemTemp.path}/vendor-upload-test-${DateTime.now().microsecondsSinceEpoch}.jpg');
  await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
  return file.path;
}

void main() {
  group('VendorAuthApi.uploadFile', () {
    test('posts multipart file + folder, returns path and url', () async {
      RequestOptions? seen;
      final api = VendorAuthApi(_stubDio(capture: (o) => seen = o));
      final path = await _tempImage();

      final result = await api.uploadFile(path);

      expect(result['path'], 'avatars/photo.jpg');
      expect(result['url'], contains('avatars/photo.jpg'));
      expect(seen?.path, '/vendor/uploads');
      final body = seen?.data as FormData;
      expect(body.files.single.key, 'file');
      expect(
        body.fields.any((f) => f.key == 'folder' && f.value == 'avatars'),
        isTrue,
      );
    });
  });

  group('StoriesApi.fetchStories', () {
    test('parses public story feed with store + link flags', () async {
      final stories = await StoriesApi(_stubDio()).fetchStories();

      expect(stories, hasLength(2));
      expect(stories.first.id, 3);
      expect(stories.first.storeName, 'Spice Route');
      expect(stories.first.hasLink, isTrue);
      expect(stories.last.hasLink, isFalse);
    });

    test('VendorStory.fromJson tolerates missing store', () {
      final story = VendorStory.fromJson({'id': 1});
      expect(story.storeName, isNull);
      expect(story.hasLink, isFalse);
      expect(story.toJson()['id'], 1);
    });
  });

  group('StoryStrip', () {
    testWidgets('renders rail, opens preview for linked stories',
        (tester) async {
      // Null thumbnails: keeps the test offline (no Image.network fetch).
      final stories = [
        {
          'id': 3,
          'store': {'id': 7, 'name': 'Spice Route'},
          'video_url': 'https://cdn.example/s3.mp4',
          'thumbnail': null,
        },
        {
          'id': 2,
          'store': {'id': 9, 'name': 'Crumb House'},
          'video_url': null,
          'thumbnail': null,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoryStrip(stories: stories),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spice Route'), findsOneWidget);
      expect(find.text('Crumb House'), findsOneWidget);

      await tester.tap(find.text('Spice Route'));
      await tester.pumpAndSettle();
      expect(find.text('https://cdn.example/s3.mp4'), findsOneWidget);
    });
  });
}
