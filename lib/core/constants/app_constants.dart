class AppConstants {
  // Booking status strings (match API response values)
  static const String statusConfirmed = 'CONFIRMED';
  static const String statusCancelled = 'CANCELLED';
  static const String statusCompleted = 'COMPLETED';
  static const String statusPending = 'PENDING';
  static const String statusNotSpecified = 'NO_STATUS';

  // Vehicle type IDs (from Android Constants.java)
  static const int vehicleTypeOpen = 1300;
  static const int vehicleTypeClosed = 1301;

  // External web URLs loaded in WebView screens
  static const String helpUrl = 'http://pickcargo.in/Dashboard/helpmobile';
  static const String rateCardUrl = 'http://pickcargo.in/RateCard/mobile';
  static const String termsAndConditionsUrl =
      'http://pickcargo.in/dashboard/mobiletermsandconditions';

  // CCAvenue payment gateway URL
  static const String ccAvenueTransUrl =
      'https://secure.ccavenue.com/transaction/initTrans';

  // Notification event strings (from Android FCM / polling logic)
  static const String notifBookingConfirmed = 'Booking Confirmed';
  static const String notifBookingFailed = 'Booking Failed';
  static const String notifBookingCancelledByDriver =
      'Booking Cancelled by driver';
  static const String notifTripStarted = 'Trip Started';
  static const String notifTripEnd = 'Trip End';
  static const String notifDriverReachedPickup =
      'Driver has reached pick up location';
  static const String notifDriverReachedDrop =
      'Driver reached delivery location';
  static const String notifInvoiceGenerated = 'Invoice Generated';
  static const String notifGenerateInvoice = 'DriverpaymentReceived';
  static const String notifAboutToReachPickup =
      'Driver is about to reach pickup location';

  // Notification payload keys
  static const String notifBodyKey = 'body';
  static const String notifBookingNoKey = 'bookingNo';

  // Token expiry response string
  static const String tokenExpired = 'INVALID MOBILENO OR AUTH TOKEN';

  // Predefined driver feedback options (shown in rating screen)
  static const List<String> driverFeedbackOptions = [
    'Driver is late',
    'Driver attitude was not good',
    'Driver was drunk',
    'Driver behaviour was not good',
  ];

  // Formatting constants
  static const String rupeeSymbol = '₹';
  static const String dateSeparator = '/';
  static const String timeSeparator = ':';

  // App name
  static const String appName = 'Pick-C';
}
