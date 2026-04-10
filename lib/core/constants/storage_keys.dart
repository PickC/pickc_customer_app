/// All SharedPreferences / SecureStorage key strings.
/// Derived from Android CredentialManager.java and HomeActivity.java
class StorageKeys {
  // Secure storage (flutter_secure_storage)
  static const String authToken = 'Auth_token_key';
  static const String password = 'password';

  // Regular SharedPreferences (shared_preferences)
  static const String mobileNo = 'Mobile_No_key';
  static const String bookingNo = 'booking_no';
  static const String tripId = 'trip_id';
  static const String name = 'name';
  static const String email = 'email';
  static const String driverId = 'driver_id';
  static const String toLat = 'to_lat';
  static const String toLong = 'to_long';
  static const String deviceId = 'device_id';
  static const String selectedVehicleGroupId = 'SelectedVehicleGroupID';
  static const String selectedVehicleTypeId = 'SelectedVehicleTypeID';
  static const String selectedTruckWeightDesc = 'SelectedTruckWeightDesc';
  static const String isBookingLater = 'IsBookingLater';
  static const String loadingUnloadingStatus = 'LoadingUnloadingStatus';
  static const String callBookNowApi = 'CallBookNowAPI';
  static const String fromLat = 'FROMLAT';
  static const String fromLng = 'FROMLNG';
  static const String vehicleType = 'VEHCILETYPE';
  static const String splash = 'splash';
  static const String showingLiveUpdateMarker = 'ShowingLiveUpdateMarker';
  static const String driverRating = 'DRIVER_RATING';
  static const String isAppInBackground = 'isInBg';
  static const String isInTrip = 'isInTrip';
  static const String entryCount = 'cnt';
  static const String bookingState = 'bookingState';
  static const String announcementEnabled = 'announcement_shared_pref_key';
  static const String volumeStatus = 'volumeStatus';
}
