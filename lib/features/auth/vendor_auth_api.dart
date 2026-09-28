// DDE-Mart vendor app — workforce auth API (original).
//
// OTP-only login with role=vendor (owner accounts use role=owner against the
// same surfaces). Mirrors POST /api/v1/work/auth/*.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class VendorAuthApi {
  VendorAuthApi(this._dio);

  final Dio _dio;

  Future<String?> otpRequest({required String phone, required String role}) async {
    final response = await _dio.post(
      '/work/auth/otp/request',
      data: {'phone': phone, 'role': role},
    );
    final data = (response.data as Map)['data'] as Map;
    return data['debug_code'] as String?;
  }

  Future<Map<String, dynamic>> otpVerify({
    required String phone,
    required String role,
    required String code,
  }) async {
    final response = await _dio.post(
      '/work/auth/otp/verify',
      data: {'phone': phone, 'role': role, 'code': code},
    );
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }

  Future<void> logout() async {
    await _dio.post('/vendor/logout');
  }

  Future<Map<String, dynamic>> updateProfile(
      {String? name, String? email}) async {
    final response = await _dio.put('/vendor/profile', data: {
      'name': ?name,
      'email': ?email,
    });
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _dio.get('/vendor/me');
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }

  /// Upload an image (POST /vendor/uploads, multipart `file` field).
  /// Returns a map with the storage `path` and the public `url`.
  /// NOTE: PUT /vendor/profile accepts name + email only, so an uploaded
  /// avatar path has nowhere to persist server-side yet — callers should
  /// treat the result as a preview until the backend accepts an avatar.
  Future<Map<String, String>> uploadFile(
    String path, {
    String folder = 'avatars',
  }) async {
    final file = await MultipartFile.fromFile(
      path,
      filename: path.split('/').last,
    );
    final response = await _dio.post(
      '/vendor/uploads',
      data: FormData.fromMap({'file': file, 'folder': folder}),
    );
    final data = Map<String, dynamic>.from(
      (response.data as Map)['data'] as Map,
    );
    return {'path': '${data['path']}', 'url': '${data['url']}'};
  }
}

final vendorAuthApiProvider = Provider<VendorAuthApi>(
  (ref) => VendorAuthApi(ref.watch(dioProvider)),
);
