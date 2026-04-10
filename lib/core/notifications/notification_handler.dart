import '../constants/app_constants.dart';

/// Routes notification payloads to appropriate actions.
/// Maps Android FCM event strings to local notification triggers.
class NotificationHandler {
  static int _getNotifId(String event) {
    // Unique IDs per event type
    switch (event) {
      case AppConstants.notifBookingConfirmed:
        return 1;
      case AppConstants.notifBookingFailed:
        return 2;
      case AppConstants.notifBookingCancelledByDriver:
        return 3;
      case AppConstants.notifTripStarted:
        return 4;
      case AppConstants.notifTripEnd:
        return 5;
      case AppConstants.notifDriverReachedPickup:
        return 6;
      case AppConstants.notifDriverReachedDrop:
        return 7;
      case AppConstants.notifInvoiceGenerated:
        return 8;
      case AppConstants.notifAboutToReachPickup:
        return 9;
      default:
        return 99;
    }
  }

  static String _getTitleForEvent(String event) {
    switch (event) {
      case AppConstants.notifBookingConfirmed:
        return 'Booking Confirmed';
      case AppConstants.notifBookingFailed:
        return 'Booking Failed';
      case AppConstants.notifBookingCancelledByDriver:
        return 'Booking Cancelled';
      case AppConstants.notifTripStarted:
        return 'Trip Started';
      case AppConstants.notifTripEnd:
        return 'Trip Completed';
      case AppConstants.notifDriverReachedPickup:
        return 'Driver Arrived';
      case AppConstants.notifDriverReachedDrop:
        return 'Delivered';
      case AppConstants.notifInvoiceGenerated:
        return 'Invoice Ready';
      case AppConstants.notifAboutToReachPickup:
        return 'Driver Nearby';
      default:
        return 'Pick-C';
    }
  }

  /// Returns notification id + title + body for a polling event.
  static ({int id, String title, String body}) forEvent(
      String event, String body) {
    return (
      id: _getNotifId(event),
      title: _getTitleForEvent(event),
      body: body,
    );
  }
}
