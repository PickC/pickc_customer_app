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
    // Demo bypass — use mobile: 9999999999, password: demo123
    if (mobile == '9999999999' && password == 'demo123') {
      final ls = ref.read(localStorageProvider);
      await ls.setMobileNo(mobile);
      await ls.setName('Demo User');
      await ref.read(secureStorageProvider).setAuthToken('demo-token');
      state = const AsyncData(CustomerModel(
        mobile: '9999999999', name: 'Demo User',
      ));
      return;
    }
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .login(mobile: mobile, password: password);
    state = result.fold(
      (failure) => AsyncError(failure.message, StackTrace.current),
      (customer) => AsyncData(customer),
    );
  }

  Future<void> checkNewNumber({required String mobile}) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .isNewNumber(mobile: mobile);
    state = result.fold(
      (failure) => AsyncError(failure.message, StackTrace.current),
      (_) => const AsyncData(null),
    );
  }

  Future<void> verifyOtp({required String mobile, required String otp}) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .verifyOtp(mobile: mobile, otp: otp);
    state = result.fold(
      (failure) => AsyncError(failure.message, StackTrace.current),
      (_) => const AsyncData(null),
    );
  }

  Future<void> generateOtp({required String mobile}) async {
    state = const AsyncLoading();
    final result =
        await ref.read(authRepositoryProvider).generateOtp(mobile: mobile);
    state = result.fold(
      (failure) => AsyncError(failure.message, StackTrace.current),
      (_) => const AsyncData(null),
    );
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, CustomerModel?>(AuthNotifier.new);
