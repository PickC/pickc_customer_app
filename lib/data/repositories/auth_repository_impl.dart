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
      return Left(ServerFailure(
          e.response?.data?.toString() ?? e.message ?? 'Login failed'));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> isNewNumber({required String mobile}) async {
    try {
      final result = await _remote.isNewNumber(mobile: mobile);
      return Right(result);
    } on DioException catch (e) {
      return Left(ServerFailure(
          e.response?.data?.toString() ?? e.message ?? 'Check failed'));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> generateOtp({required String mobile}) async {
    try {
      await _remote.generateOtp(mobile: mobile);
      return const Right(null);
    } on DioException catch (e) {
      return Left(
          ServerFailure(e.response?.data?.toString() ?? 'OTP send failed'));
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
      return Left(
          ServerFailure(e.response?.data?.toString() ?? 'OTP verify failed'));
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
