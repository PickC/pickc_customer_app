import 'package:shared_preferences/shared_preferences.dart';
import '../constants/storage_keys.dart';

class LocalStorage {
  final SharedPreferences _prefs;

  LocalStorage(this._prefs);

  // Mobile number
  String? getMobileNo() => _prefs.getString(StorageKeys.mobileNo);
  Future<void> setMobileNo(String v) => _prefs.setString(StorageKeys.mobileNo, v);

  // Booking number
  String? getBookingNo() => _prefs.getString(StorageKeys.bookingNo);
  Future<void> setBookingNo(String v) => _prefs.setString(StorageKeys.bookingNo, v);

  // Trip ID
  String? getTripId() => _prefs.getString(StorageKeys.tripId);
  Future<void> setTripId(String v) => _prefs.setString(StorageKeys.tripId, v);

  // Name
  String? getName() => _prefs.getString(StorageKeys.name);
  Future<void> setName(String v) => _prefs.setString(StorageKeys.name, v);

  // Email
  String? getEmail() => _prefs.getString(StorageKeys.email);
  Future<void> setEmail(String v) => _prefs.setString(StorageKeys.email, v);

  // Driver ID
  String? getDriverId() => _prefs.getString(StorageKeys.driverId) ?? '';
  Future<void> setDriverId(String v) => _prefs.setString(StorageKeys.driverId, v);

  // To location (destination)
  double getToLat() => double.tryParse(_prefs.getString(StorageKeys.toLat) ?? '0') ?? 0;
  Future<void> setToLat(double v) => _prefs.setString(StorageKeys.toLat, v.toString());
  double getToLong() => double.tryParse(_prefs.getString(StorageKeys.toLong) ?? '0') ?? 0;
  Future<void> setToLong(double v) => _prefs.setString(StorageKeys.toLong, v.toString());

  // From location (pickup)
  double getFromLat() => double.tryParse(_prefs.getString(StorageKeys.fromLat) ?? '0') ?? 0;
  Future<void> setFromLat(double v) => _prefs.setString(StorageKeys.fromLat, v.toString());
  double getFromLong() => double.tryParse(_prefs.getString(StorageKeys.fromLng) ?? '0') ?? 0;
  Future<void> setFromLong(double v) => _prefs.setString(StorageKeys.fromLng, v.toString());

  // Vehicle selection
  int getSelectedVehicleGroupId() => _prefs.getInt(StorageKeys.selectedVehicleGroupId) ?? 0;
  Future<void> setSelectedVehicleGroupId(int v) => _prefs.setInt(StorageKeys.selectedVehicleGroupId, v);

  int getSelectedVehicleTypeId() => _prefs.getInt(StorageKeys.selectedVehicleTypeId) ?? 0;
  Future<void> setSelectedVehicleTypeId(int v) => _prefs.setInt(StorageKeys.selectedVehicleTypeId, v);

  String? getSelectedTruckWeightDesc() => _prefs.getString(StorageKeys.selectedTruckWeightDesc);
  Future<void> setSelectedTruckWeightDesc(String v) => _prefs.setString(StorageKeys.selectedTruckWeightDesc, v);

  int getVehicleType() => _prefs.getInt(StorageKeys.vehicleType) ?? 1300;
  Future<void> setVehicleType(int v) => _prefs.setInt(StorageKeys.vehicleType, v);

  // Booking options
  bool getIsBookingLater() => _prefs.getBool(StorageKeys.isBookingLater) ?? false;
  Future<void> setIsBookingLater(bool v) => _prefs.setBool(StorageKeys.isBookingLater, v);

  int getLoadingUnloadingStatus() => _prefs.getInt(StorageKeys.loadingUnloadingStatus) ?? 0;
  Future<void> setLoadingUnloadingStatus(int v) => _prefs.setInt(StorageKeys.loadingUnloadingStatus, v);

  bool getCallBookNowApi() => _prefs.getBool(StorageKeys.callBookNowApi) ?? false;
  Future<void> setCallBookNowApi(bool v) => _prefs.setBool(StorageKeys.callBookNowApi, v);

  // App state
  bool getSplash() => _prefs.getBool(StorageKeys.splash) ?? false;
  Future<void> setSplash(bool v) => _prefs.setBool(StorageKeys.splash, v);

  bool getShowingLiveUpdateMarker() => _prefs.getBool(StorageKeys.showingLiveUpdateMarker) ?? false;
  Future<void> setShowingLiveUpdateMarker(bool v) => _prefs.setBool(StorageKeys.showingLiveUpdateMarker, v);

  String getDriverRating() => _prefs.getString(StorageKeys.driverRating) ?? '0';
  Future<void> setDriverRating(String v) => _prefs.setString(StorageKeys.driverRating, v);

  bool isAppInBackground() => _prefs.getBool(StorageKeys.isAppInBackground) ?? false;
  Future<void> setAppInBackground(bool v) => _prefs.setBool(StorageKeys.isAppInBackground, v);

  bool isInTrip() => _prefs.getBool(StorageKeys.isInTrip) ?? false;
  Future<void> setIsInTrip(bool v) => _prefs.setBool(StorageKeys.isInTrip, v);

  int getEntryCount() => _prefs.getInt(StorageKeys.entryCount) ?? 1;
  Future<void> setEntryCount(int v) => _prefs.setInt(StorageKeys.entryCount, v);

  int getBookingState() => _prefs.getInt(StorageKeys.bookingState) ?? 0;
  Future<void> setBookingState(int v) => _prefs.setInt(StorageKeys.bookingState, v);

  bool getAnnouncementEnabled() => _prefs.getBool(StorageKeys.announcementEnabled) ?? false;
  Future<void> setAnnouncementEnabled(bool v) => _prefs.setBool(StorageKeys.announcementEnabled, v);

  String? getDeviceId() => _prefs.getString(StorageKeys.deviceId);
  Future<void> setDeviceId(String v) => _prefs.setString(StorageKeys.deviceId, v);

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
