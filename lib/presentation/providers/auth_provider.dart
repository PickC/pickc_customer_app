import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/demo_mode.dart';
import '../../data/datasources/remote/auth_remote_datasource.dart';
import '../../data/models/auth/customer_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../demo/mock_data.dart';
import 'providers.dart';

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  return AuthRemoteDatasource(ref.watch(dioClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(authRemoteDatasourceProvider),
    ref.watch(secureStorageProvider),
    ref.watch(localStorageProvider),
  );
});

class AuthNotifier extends AsyncNotifier<CustomerModel?> {
  @override
  Future<CustomerModel?> build() async {
    if (kDemoMode) {
      final ls = ref.read(localStorageProvider);
      await ls.setMobileNo(MockData.customer.mobile ?? '');
      await ls.setName(MockData.customer.name ?? '');
      await ls.setEmail(MockData.customer.email ?? '');
      await ref.read(secureStorageProvider).setAuthToken('demo-token');
      return MockData.customer;
    }
    return null;
  }

  Future<void> login({required String mobile, required String password}) async {
    if (mobile == '9999999999' && password == 'demo123') {
      final ls = ref.read(localStorageProvider);
      await ls.setMobileNo(mobile);
      await ls.setName('Demo User');
      await ref.read(secureStorageProvider).setAuthToken('demo-token');
      state = const AsyncData(CustomerModel(mobile: '9999999999', name: 'Demo User'));
      return;
    }
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).login(mobile: mobile, password: password);
    state = result.fold(
      (failure) => AsyncError(failure.message, StackTrace.current),
      (customer) => AsyncData(customer),
    );
  }

  /// Step 1 — returns true if mobile is new (404), false if already registered (200).
  /// Sets state to AsyncError on network/server failures.
  Future<bool> checkNewNumber({required String mobile}) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).isNewNumber(mobile: mobile);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (isNew) {
        state = const AsyncData(null);
        return isNew;
      },
    );
  }

  /// Step 2 — sends OTP. Returns true on success, false on failure.
  Future<bool> sendOtp({required String mobile}) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).generateOtp(mobile: mobile);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }

  /// Step 3 — verifies OTP. Returns true if verified, false if invalid.
  Future<bool> verifyOtp({required String mobile, required String otp}) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).verifyOtp(mobile: mobile, otp: otp);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (verified) {
        state = const AsyncData(null);
        return verified;
      },
    );
  }

  /// Step 4 — registers customer. Returns true on success.
  Future<bool> registerCustomer({
    required String mobile,
    required String name,
    required String email,
    required String password,
    required String deviceId,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).saveCustomer(
      mobile: mobile,
      name: name,
      email: email,
      password: password,
      deviceId: deviceId,
    );
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }

  // Legacy — kept for forgot-password flow
  Future<void> generateOtp({required String mobile}) async {
    await sendOtp(mobile: mobile);
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, CustomerModel?>(AuthNotifier.new);
