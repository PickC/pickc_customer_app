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
          // Skip auth headers for public endpoints (no token available)
          final path = options.path;
          final isPublicEndpoint = path.startsWith('auth/') && !path.contains('auth/logout') ||
              path == ApiConstants.saveCustomer ||       // POST master/customers — signup
              path.startsWith(ApiConstants.getCustomer.split('{')[0]); // GET master/customers/{no}
          if (!isPublicEndpoint) {
            final token = await _secureStorage.getAuthToken();
            final mobile = await _secureStorage.getMobileNo();
            // Only add auth headers when a valid token exists
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
              if (mobile != null) options.headers['MOBILENO'] = mobile;
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
