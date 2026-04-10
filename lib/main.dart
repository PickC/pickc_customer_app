import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';
import 'core/storage/local_storage.dart';
import 'core/storage/secure_storage.dart';
import 'core/network/dio_client.dart';
import 'core/network/network_info.dart';
import 'presentation/providers/providers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init notifications
  await NotificationService().initialize();

  // Init shared preferences
  final prefs = await SharedPreferences.getInstance();
  final secureStorage = SecureStorage(const FlutterSecureStorage());
  final localStorage = LocalStorage(prefs);
  final dioClient = DioClient(secureStorage);
  final networkInfo = NetworkInfoImpl(Connectivity());

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageInstanceProvider.overrideWithValue(const FlutterSecureStorage()),
        localStorageProvider.overrideWithValue(localStorage),
        secureStorageProvider.overrideWithValue(secureStorage),
        dioClientProvider.overrideWithValue(dioClient),
        networkInfoProvider.overrideWithValue(networkInfo),
      ],
      child: const PickCApp(),
    ),
  );
}
