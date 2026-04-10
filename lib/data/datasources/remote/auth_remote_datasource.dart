import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../models/auth/customer_model.dart';

class AuthRemoteDatasource {
  final DioClient _dioClient;

  AuthRemoteDatasource(this._dioClient);

  Dio get _dio => _dioClient.dio;

  // POST auth/customer/login
  Future<CustomerModel> login({
    required String mobile,
    required String password,
  }) async {
    double lat = 0, lng = 0;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        ).timeout(const Duration(seconds: 5));
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {
      // GPS unavailable — send 0,0
    }
    final response = await _dio.post(
      ApiConstants.login,
      data: {
        'mobileNo': mobile,
        'password': password,
        'latitude': lat,
        'longitude': lng,
      },
    );
    return CustomerModel.fromJson(response.data as Map<String, dynamic>);
  }

  // GET master/customers/{mobileNo} — 404 means new number
  Future<bool> isNewNumber({required String mobile}) async {
    try {
      final url = ApiConstants.getCustomer.replaceAll('{mobileNo}', mobile);
      await _dio.get(url);
      return false; // customer exists
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return true; // new number
      rethrow;
    }
  }

  // POST master/customers
  Future<CustomerModel> saveCustomer({
    required String mobile,
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiConstants.saveCustomer,
      data: {
        'mobileNo': mobile,
        'name': name,
        'emailID': email,
        'password': password,
      },
    );
    return CustomerModel.fromJson(response.data as Map<String, dynamic>);
  }

  // POST auth/otp/send
  Future<void> generateOtp({required String mobile}) async {
    await _dio.post(ApiConstants.sendOtp, data: {
      'mobileNo': mobile,
      'userType': 'CUSTOMER',
    });
  }

  // POST auth/otp/verify
  Future<bool> verifyOtp({
    required String mobile,
    required String otp,
  }) async {
    final response = await _dio.post(ApiConstants.verifyOtp, data: {
      'mobileNo': mobile,
      'otp': otp,
      'userType': 'CUSTOMER',
    });
    return response.data == true || response.data.toString() == 'true';
  }

  // PUT master/customers/password
  Future<void> resetPassword({
    required String mobile,
    required String newPassword,
  }) async {
    await _dio.put(ApiConstants.updatePassword, data: {
      'mobileNo': mobile,
      'newPassword': newPassword,
    });
  }

  // PUT master/customers/password
  Future<void> changePassword({
    required String mobile,
    required String newPassword,
  }) async {
    await _dio.put(ApiConstants.updatePassword, data: {
      'mobileNo': mobile,
      'newPassword': newPassword,
    });
  }

  // PUT master/customers/device
  Future<void> saveDeviceId({
    required String mobile,
    required String deviceId,
  }) async {
    await _dio.put(ApiConstants.updateDeviceId, data: {
      'mobileNo': mobile,
      'deviceID': deviceId,
    });
  }

  // POST auth/logout
  Future<void> logout() async {
    await _dio.post(ApiConstants.logout);
  }
}
