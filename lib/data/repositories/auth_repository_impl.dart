import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../core/errors/failure.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_storage.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../models/auth/customer_model.dart';

class AuthRepository {
  final AuthRemoteDatasource _remote;
  final SecureStorage _secureStorage;
  final LocalStorage _localStorage;

  AuthRepository(this._remote, this._secureStorage, this._localStorage);

  /// Extracts a clean error message from a DioException.
  /// Avoids dumping raw HTML (e.g. Azure 503/403 pages) to the UI.
  String _cleanError(DioException e, String fallback) {
    final status = e.response?.statusCode;
    final data = e.response?.data?.toString() ?? '';
    if (data.trimLeft().startsWith('<')) {
      // HTML response — return a generic message based on status code
      if (status == 403) return 'Server unavailable (403). Please try again later.';
      if (status == 503) return 'Server unavailable (503). Please try again later.';
      if (status == 404) return 'Not found (404).';
      if (status == 500) return 'Internal server error. Please try again.';
      return 'Server error ($status). Please try again later.';
    }
    return data.isNotEmpty ? data : (e.message ?? fallback);
  }

  Future<Either<Failure, CustomerModel>> login({
    required String mobile,
    required String password,
  }) async {
    try {
      final customer = await _remote.login(mobile: mobile, password: password);
      // Persist credentials
      if (customer.authToken != null) {
        await _secureStorage.setAuthToken(customer.authToken!);
      }
      await _secureStorage.setMobileNo(mobile);
      await _secureStorage.setPassword(password);
      if (customer.name != null) await _localStorage.setName(customer.name!);
      if (customer.email != null) await _localStorage.setEmail(customer.email!);
      await _localStorage.setMobileNo(mobile);
      return Right(customer);
    } on DioException catch (e) {
      return Left(ServerFailure(_cleanError(e, 'Login failed')));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> isNewNumber({required String mobile}) async {
    try {
      final result = await _remote.isNewNumber(mobile: mobile);
      return Right(result);
    } on DioException catch (e) {
      return Left(ServerFailure(_cleanError(e, 'Check failed')));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> generateOtp({required String mobile}) async {
    try {
      await _remote.generateOtp(mobile: mobile);
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(_cleanError(e, 'OTP send failed')));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> verifyOtp({
    required String mobile,
    required String otp,
  }) async {
    try {
      final result = await _remote.verifyOtp(mobile: mobile, otp: otp);
      return Right(result);
    } on DioException catch (e) {
      return Left(ServerFailure(_cleanError(e, 'OTP verify failed')));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, CustomerModel>> saveCustomer({
    required String mobile,
    required String name,
    required String email,
    required String password,
    required String deviceId,
  }) async {
    try {
      final customer = await _remote.saveCustomer(
        mobile: mobile,
        name: name,
        email: email,
        password: password,
        deviceId: deviceId,
      );
      return Right(customer);
    } on DioException catch (e) {
      return Left(ServerFailure(_cleanError(e, 'Sign up failed')));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> logout() async {
    try {
      await _remote.logout();
      await _secureStorage.clearAll();
      await _localStorage.clearAll();
      return const Right(null);
    } catch (e) {
      // Still clear local data even if API fails
      await _secureStorage.clearAll();
      await _localStorage.clearAll();
      return const Right(null);
    }
  }
}
