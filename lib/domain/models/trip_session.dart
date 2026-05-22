import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Lifecycle phase of a booking. Driven by SignalR events from /hubs/booking.
enum BookingPhase {
  none,      // no active booking
  waiting,   // booking created, no driver yet
  accepted,  // driver assigned, en route to pickup
  atPickup,  // driver arrived at pickup, awaiting OTP from customer
  inTrip,    // OTP verified, trip in progress to drop
  completed, // booking finished, payment due
  cancelled, // booking cancelled by driver
}

/// Immutable snapshot of an active booking + trip. Owned by
/// [TripSessionNotifier]. Persisted to SharedPreferences on every meaningful
/// change so the customer doesn't lose OTP / driver details on app restart.
class TripSession {
  final String bookingNo;
  final String tripId;
  final String otp;
  final String driverId;
  final String driverName;
  final String driverMobile;
  final String vehicleNo;
  final int etaMinutes;
  final LatLng? driverPosition;
  final BookingPhase phase;

  const TripSession({
    this.bookingNo = '',
    this.tripId = '',
    this.otp = '',
    this.driverId = '',
    this.driverName = '',
    this.driverMobile = '',
    this.vehicleNo = '',
    this.etaMinutes = 0,
    this.driverPosition,
    this.phase = BookingPhase.none,
  });

  static const empty = TripSession();

  TripSession copyWith({
    String? bookingNo,
    String? tripId,
    String? otp,
    String? driverId,
    String? driverName,
    String? driverMobile,
    String? vehicleNo,
    int? etaMinutes,
    LatLng? driverPosition,
    BookingPhase? phase,
  }) =>
      TripSession(
        bookingNo:      bookingNo      ?? this.bookingNo,
        tripId:         tripId         ?? this.tripId,
        otp:            otp            ?? this.otp,
        driverId:       driverId       ?? this.driverId,
        driverName:     driverName     ?? this.driverName,
        driverMobile:   driverMobile   ?? this.driverMobile,
        vehicleNo:      vehicleNo      ?? this.vehicleNo,
        etaMinutes:     etaMinutes     ?? this.etaMinutes,
        driverPosition: driverPosition ?? this.driverPosition,
        phase:          phase          ?? this.phase,
      );

  bool get hasActiveBooking => bookingNo.isNotEmpty;
  bool get hasDriver => driverName.isNotEmpty || driverId.isNotEmpty;
  bool get hasLiveTrip => tripId.isNotEmpty;
}
