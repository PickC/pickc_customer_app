import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/demo_mode.dart';
import '../../domain/models/trip_session.dart';
import 'trip_session_provider.dart';
import '../../data/models/driver/driver_model.dart';
import 'providers.dart';
import 'vehicle_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum HomeState {
  idle,
  selectingTrucks,
  waitingForDriver,   // truck booked, waiting for driver to accept
  bookingConfirmed,   // driver assigned, en route to pickup
  tripActive,         // truck has started trip to drop location
  paymentDue,
}

/// Fine-grained events within a live trip — used for notifications only.
enum TripEvent {
  none,
  driverAtPickup,     // driver arrived at pickup location
  tripStarted,        // trip started, heading to drop
  vehicleAtDrop,      // vehicle reached drop location
  unloadingCargo,     // unloading in progress (if unload labour was selected)
}

/// Labour / loading-unloading option selected in the truck sheet.
enum LabourOption { none, loading, unloading, both }

/// Cargo type selected during booking.
enum CargoType { industrial, vegetables, household, fragile }

// ─────────────────────────────────────────────────────────────────────────────
// Simple state providers
// ─────────────────────────────────────────────────────────────────────────────

final homeNotifierProvider =
    NotifierProvider<HomeNotifier, HomeState>(HomeNotifier.new);

final currentDriverProvider =
    AsyncNotifierProvider<DriverNotifier, DriverModel?>(DriverNotifier.new);

/// ID of the selected vehicle group (Mini, Small, Medium, Large).
final selectedVehicleProvider = StateProvider<int?>((ref) => null);

/// lookupID for the body type: 1300 = Open, 1301 = Closed.
/// Defaults to Open when a vehicle tile is first selected.
final selectedVehicleTypeIdProvider = StateProvider<int>((ref) => 1300);
final otpProvider = StateProvider<String>((ref) => '');
final etaMinutesProvider = StateProvider<int>((ref) => 0);
/// null = user hasn't chosen yet (shown as no chip highlighted).
final labourOptionProvider =
    StateProvider<LabourOption?>((ref) => null);
final cargoTypeProvider = StateProvider<CargoType?>((ref) => null);
final cargoWeightProvider = StateProvider<String>((ref) => '');
final receiverMobileProvider = StateProvider<String?>((ref) => null);
final scheduledDateTimeProvider = StateProvider<DateTime?>((ref) => null);
final bookingCancelledProvider = StateProvider<bool>((ref) => false);

/// Non-null when a booking API error occurs — HomeScreen shows a SnackBar then clears it.
final bookingErrorProvider = StateProvider<String?>((ref) => null);

/// Non-null when the driver cancels the booking via SignalR.
/// HomeScreen listens and shows an alert dialog, then resets it.
final driverCancelMessageProvider = StateProvider<String?>((ref) => null);
final tripEventProvider = StateProvider<TripEvent>((ref) => TripEvent.none);

/// Set to amount string (e.g. '1.00') when cash payment is done.
/// HomeScreen listens to this and shows a top notification, then resets it.
final cashPaidAmountProvider = StateProvider<String?>((ref) => null);

/// Geocoded coordinates for pickup and drop locations.
final pickupLatLngProvider = StateProvider<LatLng?>((ref) => null);
final dropLatLngProvider = StateProvider<LatLng?>((ref) => null);

/// Human-readable address strings (populated from autocomplete selection).
final pickupAddressProvider = StateProvider<String>((ref) => '');
final dropAddressProvider = StateProvider<String>((ref) => '');

/// Tracks which location field the user is currently setting.
/// true = pickup, false = drop
final activeLocationFieldProvider = StateProvider<bool>((ref) => true);

/// Incremented each time the map should pan back to current GPS location.
/// HomeScreen listens and calls animateCamera when value changes.
final panToMyLocationProvider = StateProvider<int>((ref) => 0);

/// Decoded polyline point lists (filled after Directions API call).
final driverToPickupRouteProvider = StateProvider<List<LatLng>>((ref) => []);
final pickupToDropRouteProvider = StateProvider<List<LatLng>>((ref) => []);

/// Straight-line distance in km between pickup and drop (Haversine).
/// Returns null if either location is not set.
final routeDistanceKmProvider = Provider<double?>((ref) {
  final pickup = ref.watch(pickupLatLngProvider);
  final drop = ref.watch(dropLatLngProvider);
  if (pickup == null || drop == null) return null;
  const r = 6371.0;
  final dLat = (drop.latitude - pickup.latitude) * pi / 180;
  final dLon = (drop.longitude - pickup.longitude) * pi / 180;
  final lat1 = pickup.latitude * pi / 180;
  final lat2 = drop.latitude * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
});

// ─────────────────────────────────────────────────────────────────────────────
// Truck icon — loaded once from assets
// ─────────────────────────────────────────────────────────────────────────────

final truckMarkerIconProvider = FutureProvider<BitmapDescriptor>((ref) async {
  return BitmapDescriptor.asset(
    const ImageConfiguration(devicePixelRatio: 2.5, size: Size(48, 48)),
    'assets/images/open_truck_symbol_marker.png',
  );
});

final pickupMarkerIconProvider = FutureProvider<BitmapDescriptor>((ref) async {
  return BitmapDescriptor.asset(
    const ImageConfiguration(devicePixelRatio: 2.5, size: Size(48, 48)),
    'assets/images/source.png',
  );
});

final dropMarkerIconProvider = FutureProvider<BitmapDescriptor>((ref) async {
  return BitmapDescriptor.asset(
    const ImageConfiguration(devicePixelRatio: 2.5, size: Size(48, 48)),
    'assets/images/destination.png',
  );
});

/// Nearby vehicles — set from home screen after pickup is locked.
final nearbyVehicleMarkersProvider = StateProvider<Set<Marker>>((ref) => {});

/// Raw list of available on-duty driver records from the API.
/// Stored as raw maps so mapMarkersProvider can filter by vehicleGroupID on the fly.
final availableDriversDataProvider =
    StateProvider<List<Map<String, dynamic>>>((ref) => []);

// ─────────────────────────────────────────────────────────────────────────────
// Computed map providers
// ─────────────────────────────────────────────────────────────────────────────

/// Count of on-duty vehicles matching the currently selected vehicleGroup
/// and vehicleType. Used to display "N {Group} {Type} vehicles nearby".
final availableVehicleCountProvider = Provider<int>((ref) {
  final drivers       = ref.watch(availableDriversDataProvider);
  final selectedGroup = ref.watch(selectedVehicleProvider);
  final selectedType  = ref.watch(selectedVehicleTypeIdProvider);
  int count = 0;
  for (final d in drivers) {
    final lat = (d['currentLatitude'] as num?)?.toDouble()
        ?? (d['latitude'] as num?)?.toDouble();
    final lng = (d['currentLongitude'] as num?)?.toDouble()
        ?? (d['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null || lat == 0.0 || lng == 0.0) continue;
    final groupId = (d['vehicleGroup'] as num?)?.toInt()
        ?? (d['vehicleGroupID'] as num?)?.toInt();
    final typeId  = (d['vehicleType']  as num?)?.toInt();
    if (selectedGroup != null && groupId != null && groupId != selectedGroup) continue;
    if (typeId != null && typeId != selectedType) continue;
    count++;
  }
  return count;
});

/// Per-vehicleGroup count for the currently selected vehicleType.
/// Used by the vehicle tile to show "N available" per row.
final availableCountByGroupProvider = Provider<Map<int, int>>((ref) {
  final drivers      = ref.watch(availableDriversDataProvider);
  final selectedType = ref.watch(selectedVehicleTypeIdProvider);
  final counts = <int, int>{};
  for (final d in drivers) {
    final lat = (d['currentLatitude'] as num?)?.toDouble()
        ?? (d['latitude'] as num?)?.toDouble();
    final lng = (d['currentLongitude'] as num?)?.toDouble()
        ?? (d['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null || lat == 0.0 || lng == 0.0) continue;
    final groupId = (d['vehicleGroup'] as num?)?.toInt()
        ?? (d['vehicleGroupID'] as num?)?.toInt();
    final typeId  = (d['vehicleType']  as num?)?.toInt();
    if (groupId == null) continue;
    if (typeId != null && typeId != selectedType) continue;
    counts[groupId] = (counts[groupId] ?? 0) + 1;
  }
  return counts;
});

final mapMarkersProvider = Provider<Set<Marker>>((ref) {
  final homeState        = ref.watch(homeNotifierProvider);
  final pickupLatLng     = ref.watch(pickupLatLngProvider);
  final dropLatLng       = ref.watch(dropLatLngProvider);
  final driver           = ref.watch(currentDriverProvider).valueOrNull;
  final truckIcon        = ref.watch(truckMarkerIconProvider).valueOrNull;
  final pickupIcon       = ref.watch(pickupMarkerIconProvider).valueOrNull;
  final dropIcon         = ref.watch(dropMarkerIconProvider).valueOrNull;
  final nearbyMarkers    = ref.watch(nearbyVehicleMarkersProvider);
  final availDrivers     = ref.watch(availableDriversDataProvider);
  final selectedGroupId  = ref.watch(selectedVehicleProvider);       // 1000-1003 / null
  final selectedTypeId   = ref.watch(selectedVehicleTypeIdProvider); // 1300 Open / 1301 Closed

  final markers = <Marker>{};

  // ── Available on-duty vehicles (idle + selectingTrucks) ──────────────────
  if (homeState == HomeState.idle || homeState == HomeState.selectingTrucks) {
    for (final d in availDrivers) {
      final lat = (d['currentLatitude']  as num?)?.toDouble()
          ?? (d['latitude']  as num?)?.toDouble()
          ?? (d['lat']       as num?)?.toDouble();
      final lng = (d['currentLongitude'] as num?)?.toDouble()
          ?? (d['longitude'] as num?)?.toDouble()
          ?? (d['lng']       as num?)?.toDouble();
      if (lat == null || lng == null || lat == 0.0 || lng == 0.0) continue;

      // Filter by selected vehicleGroup + vehicleType when in selectingTrucks.
      // If a field is null in the response, treat as match (don't drop marker).
      final groupId = (d['vehicleGroup']   as num?)?.toInt()
          ?? (d['vehicleGroupID'] as num?)?.toInt()
          ?? (d['vehicleGroupId'] as num?)?.toInt();
      final typeId  = (d['vehicleType']    as num?)?.toInt()
          ?? (d['vehicleTypeId']  as num?)?.toInt();
      if (homeState == HomeState.selectingTrucks) {
        if (selectedGroupId != null && groupId != null && groupId != selectedGroupId) continue;
        if (typeId != null && typeId != selectedTypeId) continue;
      }

      final driverId   = (d['driverID']   ?? d['driverId']   ?? d['id'])?.toString()  ?? '';
      final driverName = (d['driverName'] ?? d['name'])?.toString() ?? 'Driver';
      final vehicleNo  = ((d['vehicleNo'] ?? d['vehicleNumber'] ?? d['regNo'])?.toString() ?? '').trim();

      markers.add(Marker(
        markerId: MarkerId('avail_$driverId'),
        position: LatLng(lat, lng),
        icon: truckIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        infoWindow: InfoWindow(
          title: driverName,
          snippet: vehicleNo.isNotEmpty ? vehicleNo : 'Available',
        ),
      ));
    }
  }

  // ── Pickup marker (selectingTrucks and beyond) ───────────────────────────
  if (pickupLatLng != null && homeState != HomeState.idle) {
    markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: pickupLatLng,
      icon: pickupIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: 'Pickup'),
    ));
  }

  // ── Drop marker (selectingTrucks and beyond) ─────────────────────────────
  if (dropLatLng != null && homeState != HomeState.idle) {
    markers.add(Marker(
      markerId: const MarkerId('drop'),
      position: dropLatLng,
      icon: dropIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(title: 'Drop'),
    ));
  }

  // ── Nearby vehicles from pickup-radius search ─────────────────────────────
  if (homeState == HomeState.selectingTrucks) {
    markers.addAll(nearbyMarkers);
  }

  // ── Assigned driver marker during active trip ─────────────────────────────
  final showDriver = homeState == HomeState.bookingConfirmed ||
      homeState == HomeState.tripActive;
  final driverLat = driver?.currentLat;
  final driverLng = driver?.currentLng;
  final driverPosValid = driverLat != null && driverLng != null &&
      driverLat.abs() > 0.001 && driverLng.abs() > 0.001;
  if (showDriver && driver != null && driverPosValid) {
    markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: LatLng(driverLat, driverLng),
      icon: truckIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      infoWindow: InfoWindow(
        title: driver.name ?? 'Driver',
        snippet: 'ETA: ${ref.read(etaMinutesProvider)} mins',
      ),
    ));
  }

  return markers;
});

final mapPolylinesProvider = Provider<Set<Polyline>>((ref) {
  final homeState = ref.watch(homeNotifierProvider);
  final driverRoute = ref.watch(driverToPickupRouteProvider);
  final tripRoute = ref.watch(pickupToDropRouteProvider);

  // Only show routes once booking is submitted (waitingForDriver and beyond)
  if (homeState == HomeState.idle || homeState == HomeState.selectingTrucks) {
    return {};
  }

  final polylines = <Polyline>{};

  // Solid black line: pickup → drop — shown from booking creation onwards
  if (tripRoute.isNotEmpty) {
    polylines.add(Polyline(
      polylineId: const PolylineId('pickup_to_drop'),
      points: tripRoute,
      color: Colors.black,
      width: 4,
    ));
  }

  // Dashed blue line: driver → pickup (only when driver en route to pickup)
  if (driverRoute.isNotEmpty && homeState == HomeState.bookingConfirmed) {
    polylines.add(Polyline(
      polylineId: const PolylineId('driver_to_pickup'),
      points: driverRoute,
      color: const Color(0xFF29B6F6),
      width: 4,
      patterns: [PatternItem.dash(18), PatternItem.gap(8)],
    ));
  }

  return polylines;
});

// ─────────────────────────────────────────────────────────────────────────────
// Text providers
// ─────────────────────────────────────────────────────────────────────────────

final tripStatusTextProvider = Provider<String>((ref) {
  final state = ref.watch(homeNotifierProvider);
  switch (state) {
    case HomeState.waitingForDriver:
      return 'Waiting for driver confirmation...';
    case HomeState.bookingConfirmed:
      return 'Pick Up Arriving';
    case HomeState.tripActive:
      return 'Trip in progress';
    default:
      return '';
  }
});

final customerNameProvider = Provider<String?>((ref) {
  return ref.watch(localStorageProvider).getName();
});

final customerMobileProvider = Provider<String?>((ref) {
  return ref.watch(localStorageProvider).getMobileNo();
});

// ─────────────────────────────────────────────────────────────────────────────
// HomeNotifier
// ─────────────────────────────────────────────────────────────────────────────

class HomeNotifier extends Notifier<HomeState> {
  Timer? _pollingTimer;
  Timer? _driverAssignTimer;
  Timer? _demoTripTimer;
  Timer? _availableDriversTimer; // polls on-duty drivers while idle

  @override
  HomeState build() {
    // React to TripSession changes from a single source of truth.
    // SignalR-driven state lives in TripSessionNotifier; we mirror it to the
    // legacy providers (otpProvider, etaMinutesProvider, currentDriverProvider)
    // so widgets don't need to change, and we react to phase transitions
    // (driver accepted, reached pickup, completed, cancelled).
    ref.listen<TripSession>(tripSessionProvider, _onTripSessionChanged,
        fireImmediately: false);
    return HomeState.idle;
  }

  // ── React to TripSession changes ──────────────────────────────────────────

  void _onTripSessionChanged(TripSession? prev, TripSession next) {
    _mirrorToLegacyProviders(prev, next);
    if (prev?.phase != next.phase) {
      _reactToPhaseChange(prev?.phase ?? BookingPhase.none, next.phase, next);
    }
  }

  void _mirrorToLegacyProviders(TripSession? prev, TripSession next) {
    // OTP is hidden from the UI until the driver actually arrives at pickup.
    // The TripSession still captures it from the BookingAccepted payload (so
    // we don't lose it if the app is killed mid-trip), but it isn't revealed
    // via otpProvider until phase >= atPickup. Driver keys it in on arrival.
    final shouldShowOtp = next.phase.index >= BookingPhase.atPickup.index &&
                          next.phase.index <= BookingPhase.completed.index;
    final visibleOtp = shouldShowOtp ? next.otp : '';
    if (ref.read(otpProvider) != visibleOtp) {
      ref.read(otpProvider.notifier).state = visibleOtp;
    }
    if (prev?.etaMinutes != next.etaMinutes) {
      ref.read(etaMinutesProvider.notifier).state = next.etaMinutes;
    }

    final identityChanged = prev?.driverId     != next.driverId
                         || prev?.driverName   != next.driverName
                         || prev?.driverMobile != next.driverMobile
                         || prev?.vehicleNo    != next.vehicleNo;
    final positionChanged = prev?.driverPosition != next.driverPosition;

    if (!next.hasDriver) {
      if (prev?.hasDriver == true) ref.invalidate(currentDriverProvider);
    } else if (identityChanged) {
      // Full reload when driver identity changes
      ref.read(currentDriverProvider.notifier).loadDriver(
            bookingNo: next.bookingNo,
            position: next.driverPosition,
            driverData: {
              'driverId':      next.driverId,
              'driverName':    next.driverName,
              'driverMobile':  next.driverMobile,
              'vehicleNumber': next.vehicleNo,
              'currentLat':    next.driverPosition?.latitude,
              'currentLng':    next.driverPosition?.longitude,
            },
          );
    } else if (positionChanged && next.driverPosition != null) {
      // Position-only update — cheap, no async fetch
      ref.read(currentDriverProvider.notifier).updatePosition(
            next.driverPosition!.latitude,
            next.driverPosition!.longitude,
          );
    }
  }

  void _reactToPhaseChange(
      BookingPhase prev, BookingPhase next, TripSession session) {
    switch (next) {
      case BookingPhase.accepted:
        if (state == HomeState.waitingForDriver) {
          state = HomeState.bookingConfirmed;
          startPolling();
          if (session.driverPosition != null) {
            _fetchRoutes(session.driverPosition!);
          }
        }
      case BookingPhase.atPickup:
        ref.read(tripEventProvider.notifier).state = TripEvent.driverAtPickup;
      case BookingPhase.completed:
        state = HomeState.paymentDue;
      case BookingPhase.cancelled:
        ref.read(driverToPickupRouteProvider.notifier).state = [];
        ref.read(tripEventProvider.notifier).state = TripEvent.none;
        stopPolling();
        ref.read(driverCancelMessageProvider.notifier).state =
            'Your booking was cancelled by the driver. Please try booking again.';
        state = HomeState.selectingTrucks;
        // Hub teardown + disk wipe — listener will fire again with phase=none,
        // which has no case here so it's a no-op.
        unawaited(ref.read(tripSessionProvider.notifier).clear());
      case BookingPhase.none:
      case BookingPhase.waiting:
      case BookingPhase.inTrip:
        break;
    }
  }

  void goToIdle() {
    _cancelAllTimers();
    state = HomeState.idle;
    startAvailableDriversPolling();
  }

  void onLocationsSet({
    required String pickupAddress,
    required String dropAddress,
  }) {
    state = HomeState.selectingTrucks;
    // Fire-and-forget — populate nearby vehicle markers from the pickup point
    final pickup = ref.read(pickupLatLngProvider);
    if (pickup != null) {
      _fetchNearbyBookingMarkers(pickup);
    }
  }

  /// Calls the nearby-bookings endpoint centred on [pickup] with a 5 km radius
  /// and converts the results into map markers stored in [nearbyVehicleMarkersProvider].
  Future<void> _fetchNearbyBookingMarkers(LatLng pickup) async {
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.get(
        ApiConstants.nearbyBookings,
        queryParameters: {
          'lat': pickup.latitude,
          'lng': pickup.longitude,
          'range': 5,
        },
      );

      final list = response.data as List<dynamic>? ?? [];
      if (list.isEmpty) return;

      // Reuse the truck icon if it's already loaded
      final truckIcon = ref.read(truckMarkerIconProvider).valueOrNull;

      final markers = <Marker>{};
      for (int i = 0; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>;
        final lat = (item['latitude'] as num?)?.toDouble();
        final lng = (item['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final bookingNo = item['bookingNo'] as String? ?? 'nearby_$i';
        final distKm    = (item['distanceKm'] as num?)?.toStringAsFixed(1) ?? '?';

        markers.add(Marker(
          markerId: MarkerId('nearby_$bookingNo'),
          position: LatLng(lat, lng),
          icon: truckIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: InfoWindow(
            title: 'Pickup nearby',
            snippet: '$distKm km away',
          ),
        ));
      }

      ref.read(nearbyVehicleMarkersProvider.notifier).state = markers;
    } catch (e) {
      debugPrint('[nearbyBookings] fetch error: $e');
      // Non-fatal — map just shows no nearby markers
    }
  }

  void selectVehicle(dynamic vehicle) {
    ref.read(selectedVehicleProvider.notifier).state = vehicle.id as int?;
    // Reset body type to Open (1300) whenever the vehicle group changes
    ref.read(selectedVehicleTypeIdProvider.notifier).state = 1300;
  }

  Future<void> confirmBooking() async {
    state = HomeState.waitingForDriver;

    final dio = ref.read(dioClientProvider).dio;
    final localStorage = ref.read(localStorageProvider);
    final mobile = localStorage.getMobileNo() ?? '';

    final pickup = ref.read(pickupLatLngProvider);
    final drop = ref.read(dropLatLngProvider);
    final pickupAddress = ref.read(pickupAddressProvider);
    final dropAddress = ref.read(dropAddressProvider);
    final vehicleGroupId  = ref.read(selectedVehicleProvider);       // mini/small/medium/large group ID
    final vehicleTypeCode = ref.read(selectedVehicleTypeIdProvider);  // 1300=Open, 1301=Closed
    final cargoCode       = ref.read(selectedCargoCodeProvider) ?? '';   // string code the API expects for cargoType
    final labour = ref.read(labourOptionProvider); // fallback index if loading lookup not yet set
    final weight = ref.read(cargoWeightProvider);
    final receiverMobile = ref.read(receiverMobileProvider);
    final scheduledAt = ref.read(scheduledDateTimeProvider);

    // Persist locations so they survive app restart
    if (pickup != null) {
      await localStorage.setFromLat(pickup.latitude);
      await localStorage.setFromLong(pickup.longitude);
    }
    if (drop != null) {
      await localStorage.setToLat(drop.latitude);
      await localStorage.setToLong(drop.longitude);
    }

    final payload = {
      'customerID': mobile,
      'locationFrom': pickupAddress,
      'locationTo': dropAddress,
      'latitude': pickup?.latitude ?? 0,
      'longitude': pickup?.longitude ?? 0,
      'toLatitude': drop?.latitude ?? 0,
      'toLongitude': drop?.longitude ?? 0,
      'vehicleGroup': vehicleGroupId ?? 0,   // mini/small/medium/large group ID
      'vehicleType': vehicleTypeCode,         // 1300=Open, 1301=Closed
      'loadingUnLoading': (labour ?? LabourOption.none).index, // 0=None, 1=Loading, 2=Unloading, 3=Both
      'cargoType': cargoCode,                  // string code the API expects (e.g. "Industrial")
      'payLoad': weight.trim().isEmpty ? '0' : weight.trim(), // string — API model is string
      'receiverMobileNo': receiverMobile ?? mobile,
      'requiredDate': (scheduledAt ?? DateTime.now()).toIso8601String(),
      'status': 0,
    };
    final prettyJson = const JsonEncoder.withIndent('  ').convert(payload);
    debugPrint('==== BOOKING PAYLOAD ====');
    debugPrint(prettyJson);
    debugPrint('=========================');

    try {
      final response = await dio.post(
        ApiConstants.createBooking,
        data: payload,
      );

      final bookingNo = (response.data['bookingNo'] ??
              response.data['data']?['bookingNo'] ??
              '')
          .toString();
      if (bookingNo.isNotEmpty) {
        await localStorage.setBookingNo(bookingNo);
        await localStorage.setIsInTrip(true);
      }

      // Immediately fetch pickup→drop route so the black line shows on map
      if (pickup != null && drop != null) {
        _getRoute(pickup, drop, pickupToDropRouteProvider);
      }

      // Hand off to TripSessionNotifier: owns SignalR + persistence + lifecycle.
      await ref.read(tripSessionProvider.notifier).start(bookingNo);
    } on DioException catch (e) {
      if (kDemoMode) {
        _fetchPickupToDropRoute();
        _runDemoDriverAssignment();
      } else {
        state = HomeState.selectingTrucks;
        // Extract the most useful part of the API error for display/debugging
        final apiMsg = e.response?.data?.toString() ?? e.message ?? 'Unknown error';
        debugPrint('[confirmBooking] DioException: ${e.response?.statusCode} — $apiMsg');
        ref.read(bookingErrorProvider.notifier).state = 'Booking failed: $apiMsg';
      }
    } catch (e) {
      if (kDemoMode) {
        _fetchPickupToDropRoute();
        _runDemoDriverAssignment();
      } else {
        state = HomeState.selectingTrucks;
        debugPrint('[confirmBooking] Error: $e');
        ref.read(bookingErrorProvider.notifier).state = 'Something went wrong. Please try again.';
      }
    }
  }

  void _fetchPickupToDropRoute() {
    final pickup = ref.read(pickupLatLngProvider);
    final drop = ref.read(dropLatLngProvider);
    if (pickup != null && drop != null) {
      _getRoute(pickup, drop, pickupToDropRouteProvider);
    }
  }

  /// Demo fallback: simulates 3-second driver assignment.
  void _runDemoDriverAssignment() {
    _driverAssignTimer?.cancel();
    _driverAssignTimer = Timer(const Duration(seconds: 3), () async {
      if (state != HomeState.waitingForDriver) return;

      final otp = (1000 + Random().nextInt(9000)).toString();
      ref.read(otpProvider.notifier).state = otp;
      ref.read(etaMinutesProvider.notifier).state = 11;

      final pickup = ref.read(pickupLatLngProvider);
      final driverPos = pickup != null
          ? LatLng(pickup.latitude + 0.014, pickup.longitude + 0.009)
          : const LatLng(17.4486, 78.3908);

      await ref.read(currentDriverProvider.notifier).loadDriver(
            bookingNo: 'DEMO-001',
            position: driverPos,
          );

      state = HomeState.bookingConfirmed;
      _fetchRoutes(driverPos);
      startPolling();
      _startDemoTripEvents();
    });
  }

  void _fetchRoutes(LatLng driverPos) {
    final pickup = ref.read(pickupLatLngProvider);
    final drop = ref.read(dropLatLngProvider);

    if (pickup != null) {
      _getRoute(driverPos, pickup, driverToPickupRouteProvider);
    }
    if (pickup != null && drop != null) {
      _getRoute(pickup, drop, pickupToDropRouteProvider);
    }
  }

  Future<void> _getRoute(
    LatLng from,
    LatLng to,
    StateProvider<List<LatLng>> provider,
  ) async {
    try {
      final points = PolylinePoints();
      final result = await points.getRouteBetweenCoordinates(
        googleApiKey: ApiConstants.googleMapsApiKey,
        request: PolylineRequest(
          origin: PointLatLng(from.latitude, from.longitude),
          destination: PointLatLng(to.latitude, to.longitude),
          mode: TravelMode.driving,
        ),
      );
      if (result.points.isNotEmpty) {
        ref.read(provider.notifier).state = result.points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
      } else {
        // Straight-line fallback
        ref.read(provider.notifier).state = [from, to];
      }
    } catch (_) {
      ref.read(provider.notifier).state = [from, to];
    }
  }

  /// Simulates trip events for demo: driver arrives → trip starts →
  /// reaches drop → (if unloading selected) unloading in progress.
  void _startDemoTripEvents() {
    _demoTripTimer?.cancel();
    int tick = 0;
    _demoTripTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      tick++;
      switch (tick) {
        case 1:
          // Driver has reached pickup
          ref.read(tripEventProvider.notifier).state =
              TripEvent.driverAtPickup;
        case 2:
          // Trip started — clear driverToPickup route, activate trip route
          ref.read(tripEventProvider.notifier).state = TripEvent.tripStarted;
          ref.read(driverToPickupRouteProvider.notifier).state = [];
          state = HomeState.tripActive;
          ref.read(etaMinutesProvider.notifier).state = 0;
        case 3:
          // Vehicle at drop
          ref.read(tripEventProvider.notifier).state = TripEvent.vehicleAtDrop;
        case 4:
          // Unloading if selected
          final labour = ref.read(labourOptionProvider);
          if (labour != null && (labour == LabourOption.unloading ||
              labour == LabourOption.both)) {
            ref.read(tripEventProvider.notifier).state =
                TripEvent.unloadingCargo;
          }
          _demoTripTimer?.cancel();
          // After 4 s, mark trip as payment due → triggers "Trip Completed" dialog
          Timer(const Duration(seconds: 4), () {
            if (state == HomeState.tripActive) {
              state = HomeState.paymentDue;
            }
          });
        default:
          break;
      }
    });
  }

  /// Resets all trip state back to idle — call after payment is done.
  void resetAfterPayment() {
    _cancelAllTimers();
    // Trip-session hubs + disk snapshot — single source of truth
    unawaited(ref.read(tripSessionProvider.notifier).clear());
    ref.read(otpProvider.notifier).state = '';
    ref.read(etaMinutesProvider.notifier).state = 0;
    ref.read(driverToPickupRouteProvider.notifier).state = [];
    ref.read(pickupToDropRouteProvider.notifier).state = [];
    ref.read(tripEventProvider.notifier).state = TripEvent.none;
    ref.read(pickupLatLngProvider.notifier).state = null;
    ref.read(dropLatLngProvider.notifier).state = null;
    ref.read(selectedVehicleProvider.notifier).state = null;
    ref.read(selectedVehicleTypeIdProvider.notifier).state = 1300;
    ref.read(selectedCargoLookupIdProvider.notifier).state = null;
    ref.read(selectedCargoCodeProvider.notifier).state = null;
    ref.read(selectedLoadingLookupIdProvider.notifier).state = null;
    ref.read(labourOptionProvider.notifier).state = null;
    ref.read(cargoTypeProvider.notifier).state = null;
    ref.read(cargoWeightProvider.notifier).state = '';
    ref.read(receiverMobileProvider.notifier).state = null;
    ref.read(scheduledDateTimeProvider.notifier).state = null;
    state = HomeState.idle;
    startAvailableDriversPolling();
  }

  /// Called on app start. If a booking was in progress before the app was
  /// closed, restores providers and resumes the correct state.
  /// Returns true if an active booking was found and restored.
  Future<bool> restoreActiveBookingIfAny() async {
    final localStorage = ref.read(localStorageProvider);
    if (!localStorage.isInTrip()) return false;

    final bookingNo = localStorage.getBookingNo() ?? '';
    if (bookingNo.isEmpty) {
      await localStorage.setIsInTrip(false);
      return false;
    }

    // Hand off to TripSessionNotifier first: it rehydrates OTP/driver/position
    // from disk and reconnects both SignalR hubs. The listener in build() then
    // mirrors this into the legacy providers so the UI renders immediately.
    await ref.read(tripSessionProvider.notifier).restoreFromDisk();

    // Restore persisted coordinates immediately so the map has something to show
    final fromLat = localStorage.getFromLat();
    final fromLng = localStorage.getFromLong();
    final toLat   = localStorage.getToLat();
    final toLng   = localStorage.getToLong();
    if (fromLat != 0 && fromLng != 0) {
      ref.read(pickupLatLngProvider.notifier).state = LatLng(fromLat, fromLng);
    }
    if (toLat != 0 && toLng != 0) {
      ref.read(dropLatLngProvider.notifier).state = LatLng(toLat, toLng);
    }

    // OTP / driver / position already mirrored to legacy providers by the
    // tripSessionProvider listener above. No need to duplicate here.

    // Optimistically show waitingForDriver while we fetch the real status
    state = HomeState.waitingForDriver;

    try {
      final dio = ref.read(dioClientProvider).dio;
      final url = ApiConstants.getBooking.replaceAll('{bookingNo}', bookingNo);
      final response = await dio.get(url);
      final data = response.data as Map<String, dynamic>? ?? {};

      // Restore addresses from booking record if available
      final pickupAddr = data['locationFrom'] as String? ?? '';
      final dropAddr   = data['locationTo']   as String? ?? '';
      if (pickupAddr.isNotEmpty) {
        ref.read(pickupAddressProvider.notifier).state = pickupAddr;
      }
      if (dropAddr.isNotEmpty) {
        ref.read(dropAddressProvider.notifier).state = dropAddr;
      }

      // Prefer coordinates from API over cached values
      final pLat = (data['latitude']    as num?)?.toDouble();
      final pLng = (data['longitude']   as num?)?.toDouble();
      final dLat = (data['toLatitude']  as num?)?.toDouble();
      final dLng = (data['toLongitude'] as num?)?.toDouble();
      if (pLat != null && pLng != null) {
        ref.read(pickupLatLngProvider.notifier).state = LatLng(pLat, pLng);
      }
      if (dLat != null && dLng != null) {
        ref.read(dropLatLngProvider.notifier).state = LatLng(dLat, dLng);
      }

      final status   = int.tryParse(data['status']?.toString() ?? '0') ?? 0;
      final driverId = data['driverID']?.toString() ?? '';
      final isConfirm = data['isConfirm'] as bool? ?? false;

      // Cancelled (4) or Completed (3) — clean up persisted state
      if (status >= 3) {
        await localStorage.setIsInTrip(false);
        state = HomeState.idle;
        return false;
      }

      _fetchPickupToDropRoute();

      // Driver has been assigned (isConfirm=true, status 1+, or driverID present)
      if (isConfirm || status >= 1 || driverId.isNotEmpty) {
        final pickup    = ref.read(pickupLatLngProvider);
        final driverLat = (data['currentLat'] as num?)?.toDouble();
        final driverLng = (data['currentLng'] as num?)?.toDouble();
        final driverPos = (driverLat != null && driverLng != null)
            ? LatLng(driverLat, driverLng)
            : (pickup != null
                ? LatLng(pickup.latitude + 0.014, pickup.longitude + 0.009)
                : const LatLng(17.4486, 78.3908));

        if (driverId.isNotEmpty) {
          await ref.read(localStorageProvider).setDriverId(driverId);
        }
        await ref.read(currentDriverProvider.notifier).loadDriver(
          bookingNo: bookingNo,
          position: driverPos,
          driverData: data,
        );
        state = HomeState.bookingConfirmed;
        _fetchRoutes(driverPos);
        startPolling();
        // TripSession owns hub reconnection + tripId discovery now.
        // restoreFromDisk was already called at the top of this method.
      }
    } catch (_) {
      // Network unavailable — TripSession's connect is non-fatal and
      // signalr_netcore will auto-reconnect on its own retry schedule.
    }

    return true;
  }

  /// Cancels the active booking via DELETE and resets to idle.
  /// Called when the user confirms they want to close the app while a booking
  /// is in the waitingForDriver state.
  Future<void> deleteBookingOnExit() async {
    _cancelAllTimers();
    unawaited(ref.read(tripSessionProvider.notifier).clear());
    final localStorage = ref.read(localStorageProvider);
    final bookingNo    = localStorage.getBookingNo() ?? '';

    if (bookingNo.isNotEmpty) {
      try {
        final dio = ref.read(dioClientProvider).dio;
        final url = ApiConstants.deleteBooking
            .replaceAll('{bookingNo}', bookingNo);
        await dio.delete(url);
      } catch (_) {
        // Non-fatal — clean up local state regardless
      }
    }

    await localStorage.setIsInTrip(false);

    ref.read(otpProvider.notifier).state = '';
    ref.read(etaMinutesProvider.notifier).state = 0;
    ref.read(driverToPickupRouteProvider.notifier).state = [];
    ref.read(pickupToDropRouteProvider.notifier).state = [];
    ref.read(tripEventProvider.notifier).state = TripEvent.none;
    ref.read(selectedVehicleProvider.notifier).state = null;
    ref.read(selectedVehicleTypeIdProvider.notifier).state = 1300;
    ref.read(selectedCargoLookupIdProvider.notifier).state = null;
    ref.read(selectedCargoCodeProvider.notifier).state = null;
    ref.read(selectedLoadingLookupIdProvider.notifier).state = null;
    ref.read(labourOptionProvider.notifier).state = null;
    ref.read(bookingCancelledProvider.notifier).state = true;
    // Location reset + camera pan handled by HomeScreen._initLocation()
    // which is triggered when homeState → idle from a booking state.
    state = HomeState.idle;
  }

  Future<void> cancelBooking({String reason = ''}) async {
    _cancelAllTimers();
    unawaited(ref.read(tripSessionProvider.notifier).clear());

    final localStorage = ref.read(localStorageProvider);
    final bookingNo = localStorage.getBookingNo() ?? '';

    try {
      final dio = ref.read(dioClientProvider).dio;
      await dio.put(ApiConstants.cancelBooking, data: {
        'bookingNo': bookingNo,
        'cancelRemarks': reason,
      });
    } catch (_) {
      // Non-fatal — clear local state regardless
    }

    await localStorage.setIsInTrip(false);

    ref.read(otpProvider.notifier).state = '';
    ref.read(etaMinutesProvider.notifier).state = 0;
    ref.read(driverToPickupRouteProvider.notifier).state = [];
    ref.read(pickupToDropRouteProvider.notifier).state = [];
    ref.read(tripEventProvider.notifier).state = TripEvent.none;
    ref.read(selectedVehicleProvider.notifier).state = null;
    ref.read(selectedVehicleTypeIdProvider.notifier).state = 1300;
    ref.read(selectedCargoLookupIdProvider.notifier).state = null;
    ref.read(selectedCargoCodeProvider.notifier).state = null;
    ref.read(selectedLoadingLookupIdProvider.notifier).state = null;
    ref.read(labourOptionProvider.notifier).state = null;
    ref.read(bookingCancelledProvider.notifier).state = true;
    // Location reset + camera pan handled by HomeScreen._initLocation()
    // which is triggered when homeState → idle from a booking state.
    state = HomeState.idle;
    startAvailableDriversPolling();
  }

  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(milliseconds: ApiConstants.pollingIntervalMs),
      (_) => _poll(),
    );
    ref.onDispose(stopPolling);
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // ── Available drivers polling ───────────────────────────────────────────────

  void startAvailableDriversPolling() {
    _availableDriversTimer?.cancel();
    _fetchAvailableDrivers(); // fetch immediately on start
    _availableDriversTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchAvailableDrivers(),
    );
  }

  void stopAvailableDriversPolling() {
    _availableDriversTimer?.cancel();
    _availableDriversTimer = null;
  }

  Future<void> _fetchAvailableDrivers() async {
    if (state != HomeState.idle && state != HomeState.selectingTrucks) return;
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.get(ApiConstants.vehiclesOnDuty);
      final data = response.data;
      List<dynamic> raw;
      if (data is List) {
        raw = data;
      } else if (data is Map<String, dynamic>) {
        raw = (data['value'] as List<dynamic>?)
            ?? (data['data']    as List<dynamic>?)
            ?? (data['drivers'] as List<dynamic>?)
            ?? [];
      } else {
        raw = [];
      }
      final list = raw.whereType<Map<String, dynamic>>().toList();
      debugPrint('[availableDrivers] fetched ${list.length} drivers');
      if (list.isNotEmpty) debugPrint('[availableDrivers] sample: ${list.first}');
      ref.read(availableDriversDataProvider.notifier).state = list;
    } catch (e) {
      debugPrint('[availableDrivers] error: $e');
    }
  }

  void _cancelAllTimers() {
    _driverAssignTimer?.cancel();
    _demoTripTimer?.cancel();
    stopPolling();
    stopAvailableDriversPolling();
    // Booking SignalR is torn down explicitly by callers that need it
    // (cancelBooking, deleteBookingOnExit, _onBookingCompleted/Cancelled).
  }

  Future<void> _poll() async {
    if (state == HomeState.idle ||
        state == HomeState.selectingTrucks ||
        state == HomeState.waitingForDriver) {
      return;
    }

    final dio = ref.read(dioClientProvider).dio;
    final localStorage = ref.read(localStorageProvider);
    final bookingNo = localStorage.getBookingNo() ?? '';
    if (bookingNo.isEmpty) return;

    try {
      final mobile = localStorage.getMobileNo() ?? '';

      // ── Is customer still in an active trip? ───────────────────────────
      final url = ApiConstants.currentCustomerTrip
          .replaceAll('{customerMobile}', mobile);
      final tripRes = await dio.get(url);
      final tripData = tripRes.data as Map<String, dynamic>? ?? {};

      // No active trip returned → trip ended → go to payment
      final tripId = tripData['tripID']?.toString() ?? '';
      if (tripId.isEmpty && state == HomeState.tripActive) {
        state = HomeState.paymentDue;
        return;
      }

      // Driver has now started the trip → hand tripId to TripSessionNotifier
      // which connects TripHub for real-time GPS. Idempotent if already watching.
      if (tripId.isNotEmpty) {
        final currentTripId = ref.read(tripSessionProvider).tripId;
        if (currentTripId != tripId) {
          unawaited(ref.read(tripSessionProvider.notifier).attachTrip(tripId));
        }
      }

      // Driver-reached-pickup is now delivered via SignalR (DriverReachedPickup),
      // so no need to poll bookingStatus >= 2 here. Trip-end + invoice checks
      // below stay as fallback in case the SignalR BookingCompleted event is missed.

      // ── Is invoice ready? (trip ended, payment due) ───────────────────
      if (state == HomeState.tripActive && tripId.isNotEmpty) {
        final invoiceUrl =
            ApiConstants.invoiceByBooking.replaceAll('{bookingNo}', bookingNo);
        final invoiceRes = await dio.get(invoiceUrl);
        final invoiceData =
            invoiceRes.data as Map<String, dynamic>? ?? {};
        final totalAmount =
            (invoiceData['totalAmount'] as num?)?.toDouble() ?? 0;
        if (totalAmount > 0 &&
            (invoiceData['paidAmount'] == null ||
                (invoiceData['paidAmount'] as num?)?.toDouble() == 0)) {
          state = HomeState.paymentDue;
        }
      }
    } catch (_) {
      // Network hiccup — continue polling next tick
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DriverNotifier
// ─────────────────────────────────────────────────────────────────────────────

class DriverNotifier extends AsyncNotifier<DriverModel?> {
  @override
  Future<DriverModel?> build() async => null;

  /// Update only the GPS position — used by TripHub DriverLocationUpdated
  /// events to move the marker without a full driver-data reload.
  void updatePosition(double lat, double lng) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(DriverModel(
      id: current.id,
      name: current.name,
      mobile: current.mobile,
      vehicleNumber: current.vehicleNumber,
      vehicleType: current.vehicleType,
      rating: current.rating,
      currentLat: lat,
      currentLng: lng,
    ));
  }

  Future<void> loadDriver({
    required String bookingNo,
    LatLng? position,
    Map<String, dynamic>? driverData, // pre-fetched from isConfirm response
  }) async {
    state = const AsyncLoading();

    // If caller already has driver data (from isConfirm polling), use it directly
    if (driverData != null && driverData.isNotEmpty) {
      final lat = (driverData['currentLat'] as num?)?.toDouble()
          ?? position?.latitude ?? 17.4486;
      final lng = (driverData['currentLng'] as num?)?.toDouble()
          ?? position?.longitude ?? 78.3908;
      state = AsyncData(DriverModel(
        id: driverData['driverId']?.toString() ?? '',
        name: driverData['driverName'] as String? ?? 'Driver',
        mobile: driverData['driverMobile'] as String? ?? '',
        vehicleNumber: driverData['vehicleNo'] as String?
            ?? driverData['vehicleNumber'] as String? ?? '',
        vehicleType: driverData['vehicleType'] as String? ?? '',
        rating: driverData['driverRating']?.toString() ?? '0',
        currentLat: lat,
        currentLng: lng,
      ));
      return;
    }

    // Otherwise fetch from API
    try {
      final dio = ref.read(dioClientProvider).dio;
      final url = ApiConstants.getBooking.replaceAll('{bookingNo}', bookingNo);
      final response = await dio.get(url);
      final d = response.data as Map<String, dynamic>? ?? {};
      final lat = (d['currentLat'] as num?)?.toDouble()
          ?? position?.latitude ?? 17.4486;
      final lng = (d['currentLng'] as num?)?.toDouble()
          ?? position?.longitude ?? 78.3908;
      state = AsyncData(DriverModel(
        id: d['driverId']?.toString() ?? '',
        name: d['driverName'] as String? ?? 'Driver',
        mobile: d['driverMobile'] as String? ?? '',
        vehicleNumber: d['vehicleNo'] as String?
            ?? d['vehicleNumber'] as String? ?? '',
        vehicleType: d['vehicleType'] as String? ?? '',
        rating: d['driverRating']?.toString() ?? '0',
        currentLat: lat,
        currentLng: lng,
      ));
    } catch (_) {
      // Fallback to demo data
      state = AsyncData(DriverModel(
        id: 'DR170800008',
        name: 'Naresh',
        mobile: '9876543210',
        vehicleNumber: 'CGEN1127/BK171000193',
        vehicleType: 'Mini - Open Truck',
        rating: '4.0',
        currentLat: position?.latitude ?? 17.4486,
        currentLng: position?.longitude ?? 78.3908,
      ));
    }
  }
}
