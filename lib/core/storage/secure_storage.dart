import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';

class SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage(this._storage);

  Future<void> setAuthToken(String token) =>
      _storage.write(key: StorageKeys.authToken, value: token);

  Future<String?> getAuthToken() =>
      _storage.read(key: StorageKeys.authToken);

  Future<void> clearAuthToken() =>
      _storage.delete(key: StorageKeys.authToken);

  Future<void> setPassword(String password) =>
      _storage.write(key: StorageKeys.password, value: password);

  Future<String?> getPassword() =>
      _storage.read(key: StorageKeys.password);

  Future<void> setMobileNo(String mobile) =>
      _storage.write(key: StorageKeys.mobileNo, value: mobile);

  Future<String?> getMobileNo() =>
      _storage.read(key: StorageKeys.mobileNo);

  Future<void> clearAll() => _storage.deleteAll();
}
