import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/dio_client.dart';
import '../../core/network/network_info.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_storage.dart';

// Raw instances (overridden in main)
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main'),
);

final secureStorageInstanceProvider = Provider<FlutterSecureStorage>(
  (ref) => throw UnimplementedError('Override in main'),
);

// Wrapped instances
final localStorageProvider = Provider<LocalStorage>(
  (ref) => LocalStorage(ref.watch(sharedPreferencesProvider)),
);

final secureStorageProvider = Provider<SecureStorage>(
  (ref) => SecureStorage(ref.watch(secureStorageInstanceProvider)),
);

final dioClientProvider = Provider<DioClient>(
  (ref) => DioClient(ref.watch(secureStorageProvider)),
);

final networkInfoProvider = Provider<NetworkInfo>(
  (ref) => NetworkInfoImpl(Connectivity()),
);
