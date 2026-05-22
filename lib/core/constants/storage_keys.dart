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

  // Trip session snapshot — written when SignalR delivers an update, read on
  // app restart so the customer sees the same driver/OTP/position they had
  // before the process was killed.
  static const String otp           = 'session_otp';
  static const String driverName    = 'session_driver_name';
  static const String driverMobile  = 'session_driver_mobile';
  static const String vehicleNo     = 'session_vehicle_no';
  static const String etaMinutes    = 'session_eta_minutes';
  static const String driverLat     = 'session_driver_lat';
  static const String driverLng     = 'session_driver_lng';
  static const String bookingPhase  = 'session_booking_phase'; // BookingPhase.index
}
