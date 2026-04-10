import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class DioClient {
  late final Dio _dio;
  final SecureStorage _secureStorage;

  DioClient(this._secureStorage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Skip auth headers for login/otp/refresh — no token available yet
          final isAuthEndpoint = options.path.startsWith('auth/') &&
              !options.path.contains('auth/logout');
          if (!isAuthEndpoint) {
            final token = await _secureStorage.getAuthToken();
            final mobile = await _secureStorage.getMobileNo();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            if (mobile != null) {
              options.headers['MOBILENO'] = mobile;
            }
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;
}
