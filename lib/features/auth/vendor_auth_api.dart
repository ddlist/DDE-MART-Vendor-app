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
}

final vendorAuthApiProvider = Provider<VendorAuthApi>(
  (ref) => VendorAuthApi(ref.watch(dioProvider)),
);
