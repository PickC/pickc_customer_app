import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/demo_mode.dart';
import '../../data/models/driver/driver_model.dart';
import 'providers.dart';

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

final selectedVehicleProvider = StateProvider<int?>((ref) => null);
final otpProvider = StateProvider<String>((ref) => '');
final etaMinutesProvider = StateProvider<int>((ref) => 0);
final labourOptionProvider =
    StateProvider<LabourOption>((ref) => LabourOption.none);
final cargoTypeProvider = StateProvider<CargoType?>((ref) => null);
final cargoWeightProvider = StateProvider<String>((ref) => '');
final receiverMobileProvider = StateProvider<String?>((ref) => null);
final scheduledDateTimeProvider = StateProvider<DateTime?>((ref) => null);
final bookingCancelledProvider = StateProvider<bool>((ref) => false);
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

/// Decoded polyline point lists (filled after Directions API call).
final driverToPickupRouteProvider = StateProvider<List<LatLng>>((ref) => []);
final pickupToDropRouteProvider = StateProvider<List<LatLng>>((ref) => []);

// ─────────────────────────────────────────────────────────────────────────────
// Truck icon — loaded once from assets
// ─────────────────────────────────────────────────────────────────────────────

final truckMarkerIconProvider = FutureProvider<BitmapDescriptor>((ref) async {
  return BitmapDescriptor.asset(
    const ImageConfiguration(devicePixelRatio: 2.5, size: Size(56, 56)),
    'assets/trucks/mini_opened_truck.png',
  );
});

final pickupMarkerIconProvider = FutureProvider<BitmapDescriptor>((ref) async {
  return BitmapDescriptor.asset(
    const ImageConfiguration(devicePixelRatio: 2.5, size: Size(48, 48)),
    'assets/images/source2.png',
  );
});

final dropMarkerIconProvider = FutureProvider<BitmapDescriptor>((ref) async {
  return BitmapDescriptor.asset(
    const ImageConfiguration(devicePixelRatio: 2.5, size: Size(48, 48)),
    'assets/images/destination2.png',
  );
});

/// Nearby vehicles — set from home screen after pickup is locked.
final nearbyVehicleMarkersProvider = StateProvider<Set<Marker>>((ref) => {});

// ─────────────────────────────────────────────────────────────────────────────
// Computed map providers
// ─────────────────────────────────────────────────────────────────────────────

final mapMarkersProvider = Provider<Set<Marker>>((ref) {
  final homeState = ref.watch(homeNotifierProvider);
  final pickupLatLng = ref.watch(pickupLatLngProvider);
  final dropLatLng = ref.watch(dropLatLngProvider);
  final driver = ref.watch(currentDriverProvider).valueOrNull;
  final truckIcon = ref.watch(truckMarkerIconProvider).valueOrNull;
  final pickupIcon = ref.watch(pickupMarkerIconProvider).valueOrNull;
  final dropIcon = ref.watch(dropMarkerIconProvider).valueOrNull;
  final nearbyMarkers = ref.watch(nearbyVehicleMarkersProvider);

  final markers = <Marker>{};

  // Pickup marker — only when locations are locked (selectingTrucks+)
  if (pickupLatLng != null &&
      homeState != HomeState.idle) {
    markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: pickupLatLng,
      icon: pickupIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: 'Pickup'),
    ));
  }

  // Drop marker
  if (dropLatLng != null) {
    markers.add(Marker(
      markerId: const MarkerId('drop'),
      position: dropLatLng,
      icon: dropIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(title: 'Drop'),
    ));
  }

  // Nearby vehicles (shown after pickup locked, before booking)
  if (homeState == HomeState.selectingTrucks) {
    markers.addAll(nearbyMarkers);
  }

  // Driver marker during trip
  final showDriver = homeState == HomeState.bookingConfirmed ||
      homeState == HomeState.tripActive;
  if (showDriver &&
      driver != null &&
      driver.currentLat != null &&
      driver.currentLng != null) {
    markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: LatLng(driver.currentLat!, driver.currentLng!),
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

  if (homeState != HomeState.bookingConfirmed &&
      homeState != HomeState.tripActive) {
    return {};
  }

  final polylines = <Polyline>{};

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

  // Dotted grey line: pickup → drop (future route preview)
  if (tripRoute.isNotEmpty) {
    polylines.add(Polyline(
      polylineId: const PolylineId('pickup_to_drop'),
      points: tripRoute,
      color: const Color(0xFF757575),
      width: 3,
      patterns: [PatternItem.dot, PatternItem.gap(6)],
    ));
  }

  // Solid yellow line: active trip route (reuse tripRoute when tripActive)
  if (tripRoute.isNotEmpty && homeState == HomeState.tripActive) {
    polylines.add(Polyline(
      polylineId: const PolylineId('active_trip'),
      points: tripRoute,
      color: const Color(0xFFF8F206),
      width: 4,
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
  Timer? _driverConfirmTimer; // polls isConfirm after booking saved

  @override
  HomeState build() => HomeState.idle;

  void goToIdle() {
    _cancelAllTimers();
    state = HomeState.idle;
  }

  void onLocationsSet({
    required String pickupAddress,
    required String dropAddress,
  }) {
    state = HomeState.selectingTrucks;
  }

  void selectVehicle(dynamic vehicle) {
    ref.read(selectedVehicleProvider.notifier).state = vehicle.id as int?;
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
    final vehicleTypeId = ref.read(selectedVehicleProvider);
    final labour = ref.read(labourOptionProvider);
    final cargo = ref.read(cargoTypeProvider);
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

    try {
      final response = await dio.post(
        ApiConstants.createBooking,
        data: {
          'customerID': mobile,
          'locationFrom': pickupAddress,
          'locationTo': dropAddress,
          'latitude': pickup?.latitude ?? 0,
          'longitude': pickup?.longitude ?? 0,
          'toLatitude': drop?.latitude ?? 0,
          'toLongitude': drop?.longitude ?? 0,
          'vehicleType': vehicleTypeId ?? 0,
          'loadingUnLoading': labour.index, // 0=none,1=load,2=unload,3=both
          'cargoType': cargo?.name ?? '',
          'payLoad': weight,
          'receiverMobileNo': receiverMobile ?? mobile,
          'requiredDate': (scheduledAt ?? DateTime.now()).toIso8601String(),
          'status': 0,
        },
      );

      final bookingNo = (response.data['bookingNo'] ??
              response.data['data']?['bookingNo'] ??
              '')
          .toString();
      if (bookingNo.isNotEmpty) {
        await localStorage.setBookingNo(bookingNo);
        await localStorage.setIsInTrip(true);
      }

      // Poll isConfirm every 5 s until driver accepts
      _startDriverConfirmPolling(bookingNo);
    } on DioException catch (_) {
      if (kDemoMode) {
        _runDemoDriverAssignment();
      } else {
        state = HomeState.selectingTrucks;
      }
    } catch (_) {
      if (kDemoMode) {
        _runDemoDriverAssignment();
      } else {
        state = HomeState.selectingTrucks;
      }
    }
  }

  /// Polls `isConfirm/{bookingNo}` every 5 s until driver accepts.
  void _startDriverConfirmPolling(String bookingNo) {
    _driverConfirmTimer?.cancel();
    _driverConfirmTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (state != HomeState.waitingForDriver) {
        _driverConfirmTimer?.cancel();
        return;
      }
      await _checkDriverConfirmed(bookingNo);
    });
  }

  Future<void> _checkDriverConfirmed(String bookingNo) async {
    if (bookingNo.isEmpty) return;
    try {
      final dio = ref.read(dioClientProvider).dio;
      final url = ApiConstants.getBooking.replaceAll('{bookingNo}', bookingNo);
      final response = await dio.get(url);
      final data = response.data as Map<String, dynamic>? ?? {};

      // Booking is confirmed when driverID is assigned (non-null/non-empty)
      final driverId = data['driverID']?.toString() ?? '';
      final status = data['status'] as int?;
      // status: 0=pending, 1=confirmed, 2=active, 3=completed, 4=cancelled
      final isConfirmed = driverId.isNotEmpty || (status != null && status >= 1);
      if (!isConfirmed) return;

      _driverConfirmTimer?.cancel();

      // Parse driver position
      final driverLat = (data['currentLat'] as num?)?.toDouble();
      final driverLng = (data['currentLng'] as num?)?.toDouble();
      final pickup = ref.read(pickupLatLngProvider);
      final driverPos = (driverLat != null && driverLng != null)
          ? LatLng(driverLat, driverLng)
          : (pickup != null
              ? LatLng(pickup.latitude + 0.014, pickup.longitude + 0.009)
              : const LatLng(17.4486, 78.3908));

      // Generate OTP and ETA
      final otp = (1000 + Random().nextInt(9000)).toString();
      ref.read(otpProvider.notifier).state = otp;
      ref.read(etaMinutesProvider.notifier).state =
          data['etaMinutes'] as int? ?? 11;

      // Save driver ID for payment (driverId already parsed above)
      await ref.read(localStorageProvider).setDriverId(driverId);

      await ref.read(currentDriverProvider.notifier).loadDriver(
            bookingNo: bookingNo,
            position: driverPos,
            driverData: data,
          );

      state = HomeState.bookingConfirmed;
      _fetchRoutes(driverPos);
      startPolling();
      _startDemoTripEvents(); // remove when real trip events come from backend
    } catch (_) {
      // Network hiccup — next tick will retry
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
          if (labour == LabourOption.unloading ||
              labour == LabourOption.both) {
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
    ref.read(otpProvider.notifier).state = '';
    ref.read(etaMinutesProvider.notifier).state = 0;
    ref.read(driverToPickupRouteProvider.notifier).state = [];
    ref.read(pickupToDropRouteProvider.notifier).state = [];
    ref.read(tripEventProvider.notifier).state = TripEvent.none;
    ref.read(pickupLatLngProvider.notifier).state = null;
    ref.read(dropLatLngProvider.notifier).state = null;
    ref.read(selectedVehicleProvider.notifier).state = null;
    ref.read(cargoTypeProvider.notifier).state = null;
    ref.read(cargoWeightProvider.notifier).state = '';
    ref.read(receiverMobileProvider.notifier).state = null;
    ref.read(scheduledDateTimeProvider.notifier).state = null;
    state = HomeState.idle;
  }

  Future<void> cancelBooking({String reason = ''}) async {
    _cancelAllTimers();

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
    ref.read(bookingCancelledProvider.notifier).state = true;
    state = HomeState.idle;
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

  void _cancelAllTimers() {
    _driverAssignTimer?.cancel();
    _driverConfirmTimer?.cancel();
    _demoTripTimer?.cancel();
    stopPolling();
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

      // ── Has driver reached pickup? (bookingConfirmed state only) ───────
      if (state == HomeState.bookingConfirmed) {
        final bookingUrl =
            ApiConstants.getBooking.replaceAll('{bookingNo}', bookingNo);
        final bookingRes = await dio.get(bookingUrl);
        final bookingData =
            bookingRes.data as Map<String, dynamic>? ?? {};
        // status 2 = driver reached pickup / trip active
        final bookingStatus = bookingData['status'] as int? ?? 0;
        if (bookingStatus >= 2) {
          ref.read(tripEventProvider.notifier).state =
              TripEvent.driverAtPickup;
        }
      }

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
