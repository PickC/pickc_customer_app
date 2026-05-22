import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/api_constants.dart';
import '../../core/services/booking_signalr_service.dart';
import '../../core/services/signalr_service.dart';
import '../../domain/models/trip_session.dart';
import 'home_provider.dart' show pickupLatLngProvider;
import 'providers.dart';

/// Single source of truth for everything trip-related. Owns the SignalR
/// connections to both /hubs/booking and /hubs/trip, mutates [TripSession]
/// in response to events, and persists every meaningful change to disk so
/// the customer doesn't lose OTP / driver details on app kill.
///
/// HomeNotifier listens to this provider and reacts to phase transitions
/// (e.g. `accepted` → bookingConfirmed, `cancelled` → selectingTrucks alert).
final tripSessionProvider =
    NotifierProvider<TripSessionNotifier, TripSession>(TripSessionNotifier.new);

class TripSessionNotifier extends Notifier<TripSession> {
  final _bookingHub = BookingSignalRService();
  final _tripHub = SignalRService();
  DateTime _lastPositionPersist = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  TripSession build() {
    ref.onDispose(() {
      // Best-effort cleanup on hot reload / provider dispose
      _bookingHub.disconnect();
      _tripHub.disconnect();
    });
    return TripSession.empty;
  }

  // ── Public lifecycle ───────────────────────────────────────────────────────

  /// Start a brand-new booking session. Called from HomeNotifier.confirmBooking
  /// right after the POST /booking/bookings response yields a bookingNo.
  Future<void> start(String bookingNo) async {
    if (bookingNo.isEmpty) return;
    state = TripSession.empty.copyWith(
      bookingNo: bookingNo,
      phase: BookingPhase.waiting,
    );
    final ls = ref.read(localStorageProvider);
    await ls.setBookingNo(bookingNo);
    await ls.setIsInTrip(true);
    await _connectBookingHub(bookingNo);
  }

  /// Restore an in-progress booking from disk on cold start. Called from
  /// HomeNotifier.restoreActiveBookingIfAny when isInTrip==true. Returns
  /// true if a session was restored.
  Future<bool> restoreFromDisk() async {
    final ls = ref.read(localStorageProvider);
    if (!ls.isInTrip()) return false;

    final bookingNo = ls.getBookingNo() ?? '';
    if (bookingNo.isEmpty) {
      await ls.setIsInTrip(false);
      return false;
    }

    final tripId   = ls.getTripId() ?? '';
    final dLat     = ls.getDriverLat();
    final dLng     = ls.getDriverLng();
    final hasDriver = (ls.getDriverName() ?? '').isNotEmpty
        || (ls.getDriverId() ?? '').isNotEmpty;

    state = TripSession(
      bookingNo:      bookingNo,
      tripId:         tripId,
      otp:            ls.getOtp() ?? '',
      driverId:       ls.getDriverId() ?? '',
      driverName:     ls.getDriverName() ?? '',
      driverMobile:   ls.getDriverMobile() ?? '',
      vehicleNo:      ls.getVehicleNo() ?? '',
      etaMinutes:     ls.getEtaMinutes(),
      driverPosition: (dLat != 0 && dLng != 0) ? LatLng(dLat, dLng) : null,
      // Best guess from snapshot. API call (in HomeNotifier.restoreActive…)
      // will refine via the booking-detail endpoint.
      phase: hasDriver ? BookingPhase.accepted : BookingPhase.waiting,
    );

    // Reconnect SignalR so future events resume flowing
    await _connectBookingHub(bookingNo);
    if (tripId.isNotEmpty) {
      await _connectTripHub(tripId);
    } else {
      unawaited(_lookupAndAttachTripId());
    }
    return true;
  }

  /// Wipe everything: state, hubs, persisted snapshot. Single cleanup entry
  /// point — replaces the duplicated logic that used to live in cancel /
  /// exit / payment / completed / driver-cancelled paths.
  Future<void> clear() async {
    state = TripSession.empty;
    _lastPositionPersist = DateTime.fromMillisecondsSinceEpoch(0);
    await _stopBookingHub();
    await _stopTripHub();
    await ref.read(localStorageProvider).clearTripSession();
  }

  /// Called from HomeNotifier._poll when the currentCustomerTrip endpoint
  /// finally yields a tripId (driver entered OTP and trip started).
  Future<void> attachTrip(String tripId) async {
    if (tripId.isEmpty || state.tripId == tripId) return;
    state = state.copyWith(tripId: tripId);
    await ref.read(localStorageProvider).setTripId(tripId);
    await _connectTripHub(tripId);
  }

  // ── BookingHub ─────────────────────────────────────────────────────────────

  Future<void> _connectBookingHub(String bookingNo) async {
    try {
      await _bookingHub.connect(
        tokenGetter: () => ref.read(secureStorageProvider).getAuthToken(),
      );
      _bookingHub.clearListeners();
      _bookingHub.onBookingAccepted(_onBookingAccepted);
      _bookingHub.onDriverReachedPickup(_onDriverReachedPickup);
      _bookingHub.onBookingCompleted(_onBookingCompleted);
      _bookingHub.onBookingCancelled(_onBookingCancelledByDriver);
      await _bookingHub.watchBooking(bookingNo);
      debugPrint('[BookingHub] watching $bookingNo');
    } catch (e) {
      debugPrint('[BookingHub] connect failed: $e');
    }
  }

  Future<void> _stopBookingHub() async {
    if (state.bookingNo.isNotEmpty) {
      await _bookingHub.stopWatchingBooking(state.bookingNo);
    }
    _bookingHub.clearListeners();
    await _bookingHub.disconnect();
  }

  Future<void> _onBookingAccepted(BookingAcceptedEvent event) async {
    if (event.bookingNo != state.bookingNo) return;
    if (state.phase != BookingPhase.waiting &&
        state.phase != BookingPhase.accepted) return; // ignore stray dupes

    final pickup = ref.read(pickupLatLngProvider);
    // No GPS in the BookingAccepted payload — fall back to a small offset
    // from pickup. TripHub will overwrite this with real coords shortly.
    final driverPos = state.driverPosition ??
        (pickup != null
            ? LatLng(pickup.latitude + 0.014, pickup.longitude + 0.009)
            : const LatLng(17.4486, 78.3908));

    state = state.copyWith(
      otp:            event.otp,
      driverId:       event.driverId,
      driverName:     event.driverName,
      driverMobile:   event.driverMobile,
      vehicleNo:      event.vehicleNo,
      etaMinutes:     11,
      driverPosition: driverPos,
      phase:          BookingPhase.accepted,
    );

    // Persist the whole snapshot
    final ls = ref.read(localStorageProvider);
    await Future.wait([
      ls.setOtp(event.otp),
      ls.setDriverName(event.driverName),
      ls.setDriverMobile(event.driverMobile),
      ls.setVehicleNo(event.vehicleNo),
      ls.setEtaMinutes(11),
      ls.setDriverLat(driverPos.latitude),
      ls.setDriverLng(driverPos.longitude),
      if (event.driverId.isNotEmpty) ls.setDriverId(event.driverId),
    ]);

    // Driver is moving — start polling for the tripId so TripHub can engage.
    unawaited(_lookupAndAttachTripId());
  }

  void _onDriverReachedPickup(String bookingNo) {
    if (bookingNo != state.bookingNo) return;
    if (state.phase == BookingPhase.atPickup) return;
    state = state.copyWith(phase: BookingPhase.atPickup);
  }

  void _onBookingCompleted(String bookingNo) {
    if (bookingNo != state.bookingNo) return;
    if (state.phase == BookingPhase.completed) return;
    state = state.copyWith(phase: BookingPhase.completed);
    // Hub teardown happens via clear() in resetAfterPayment.
  }

  void _onBookingCancelledByDriver(String bookingNo, String by) {
    if (bookingNo != state.bookingNo) return;
    if (state.phase == BookingPhase.cancelled) return;
    state = state.copyWith(phase: BookingPhase.cancelled);
    // Disk gets cleared by clear() once the customer dismisses the alert.
  }

  // ── TripHub ────────────────────────────────────────────────────────────────

  Future<void> _connectTripHub(String tripId) async {
    if (tripId.isEmpty) return;
    if (_tripHub.isConnected) {
      // already connected — just re-arm listeners + re-watch
      _tripHub.clearListeners();
    }
    try {
      await _tripHub.connect(
        tokenGetter: () => ref.read(secureStorageProvider).getAuthToken(),
      );
      _tripHub.clearListeners();
      _tripHub.onDriverLocationUpdated(_onDriverLocationUpdated);
      _tripHub.onTripEnded((id) {
        if (id == state.tripId) {
          debugPrint('[TripHub] trip $id ended');
        }
      });
      await _tripHub.watchTrip(tripId);
      debugPrint('[TripHub] watching $tripId');
    } catch (e) {
      debugPrint('[TripHub] connect failed: $e');
    }
  }

  Future<void> _stopTripHub() async {
    if (state.tripId.isNotEmpty) {
      await _tripHub.stopWatchingTrip(state.tripId);
    }
    _tripHub.clearListeners();
    await _tripHub.disconnect();
  }

  void _onDriverLocationUpdated(
      String tripId, double lat, double lng, double? bearing, double? speed) {
    if (tripId != state.tripId) return;
    state = state.copyWith(driverPosition: LatLng(lat, lng));
    // Throttle disk writes to once per ~3s (SignalR can fire several per sec)
    final now = DateTime.now();
    if (now.difference(_lastPositionPersist).inMilliseconds >= 3000) {
      _lastPositionPersist = now;
      final ls = ref.read(localStorageProvider);
      unawaited(ls.setDriverLat(lat));
      unawaited(ls.setDriverLng(lng));
    }
  }

  /// Best-effort: ask the API for an active tripId, then start TripHub.
  /// Used after BookingAccepted and after restore-from-disk.
  Future<void> _lookupAndAttachTripId() async {
    if (state.tripId.isNotEmpty) return;
    try {
      final mobile = ref.read(localStorageProvider).getMobileNo() ?? '';
      if (mobile.isEmpty) return;
      final dio = ref.read(dioClientProvider).dio;
      final url = ApiConstants.currentCustomerTrip
          .replaceAll('{customerMobile}', mobile);
      final response = await dio.get(url);
      final data = response.data as Map<String, dynamic>? ?? {};
      final tripId = data['tripID']?.toString() ?? '';
      if (tripId.isNotEmpty) {
        await attachTrip(tripId);
      }
    } catch (e) {
      debugPrint('[TripSession] tripId lookup failed: $e');
    }
  }
}
