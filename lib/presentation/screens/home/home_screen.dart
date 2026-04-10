import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import 'booking_stepper_sheet.dart';
import 'driver_details_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(17.3850, 78.4867);
  LatLng? _mapCenter;

  // Uber-style location selection state
  bool _pickupLocked = false; // false = selecting pickup, true = selecting drop
  bool _isReverseGeocoding = false;
  String _currentAddress = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeNotifierProvider.notifier).startPolling();
      _initLocation();
    });
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentLocation = latLng;
          _mapCenter = latLng;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 15),
        );
        _reverseGeocode(latLng);
      }
    } catch (_) {}
  }

  void _onCameraMove(CameraPosition pos) {
    if (!mounted) return;
    // Only update center, no setState to avoid flicker
    _mapCenter = pos.target;
  }

  Future<void> _onCameraIdle() async {
    if (!mounted) return;
    final center = _mapCenter;
    if (center == null) return;
    final homeState = ref.read(homeNotifierProvider);
    if (homeState != HomeState.idle) return;

    if (!_pickupLocked) {
      ref.read(pickupLatLngProvider.notifier).state = center;
    } else {
      ref.read(dropLatLngProvider.notifier).state = center;
    }
    _reverseGeocode(center);
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    if (_isReverseGeocoding) return;
    _isReverseGeocoding = true;
    try {
      final response = await Dio().get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '${pos.latitude},${pos.longitude}',
          'key': ApiConstants.googleMapsApiKey,
          'language': 'en',
          'region': 'in',
        },
      );
      final results = (response.data['results'] as List?) ?? [];
      if (results.isNotEmpty && mounted) {
        final address = results[0]['formatted_address'] as String? ?? '';
        setState(() => _currentAddress = address);
        if (!_pickupLocked) {
          ref.read(pickupAddressProvider.notifier).state = address;
        } else {
          ref.read(dropAddressProvider.notifier).state = address;
        }
      }
    } catch (_) {
    } finally {
      _isReverseGeocoding = false;
    }
  }

  // ── Lock pickup location ─────────────────────────────────────────────────
  void _lockPickup() {
    final pickup = ref.read(pickupLatLngProvider);
    if (pickup == null) return;
    setState(() {
      _pickupLocked = true;
      _currentAddress = '';
    });
    // Pan slightly to leave room, reset for drop selection
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pickup, 14));
  }

  // ── Confirm drop location → go to truck selection ─────────────────────────
  Future<void> _confirmDrop() async {
    final pickup = ref.read(pickupLatLngProvider);
    final drop = ref.read(dropLatLngProvider);
    if (pickup == null || drop == null) return;

    // Fit both markers on screen
    _fitMapToMarkers();

    // Fetch nearby vehicles within 5km of pickup
    await _fetchNearbyVehicles(pickup);

    // Move to truck selection
    final pickupAddr = ref.read(pickupAddressProvider);
    final dropAddr = ref.read(dropAddressProvider);
    ref.read(homeNotifierProvider.notifier).onLocationsSet(
      pickupAddress: pickupAddr,
      dropAddress: dropAddr,
    );

    setState(() => _pickupLocked = false); // reset for next booking
  }

  Future<void> _fetchNearbyVehicles(LatLng pickup) async {
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
      final list = (response.data as List?) ?? [];
      final truckIcon = ref.read(truckMarkerIconProvider).valueOrNull;
      final markers = <Marker>{};
      for (int i = 0; i < list.length; i++) {
        final b = list[i] as Map<String, dynamic>;
        final lat = (b['latitude'] as num?)?.toDouble();
        final lng = (b['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        markers.add(Marker(
          markerId: MarkerId('nearby_$i'),
          position: LatLng(lat, lng),
          icon: truckIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: InfoWindow(title: 'Available Truck'),
          flat: true,
        ));
      }
      ref.read(nearbyVehicleMarkersProvider.notifier).state = markers;
    } catch (_) {
      // Non-fatal — no nearby vehicles shown
    }
  }

  @override
  void dispose() {
    ref.read(homeNotifierProvider.notifier).stopPolling();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeNotifierProvider);

    ref.listen<HomeState>(homeNotifierProvider, (prev, next) {
      if (next == HomeState.paymentDue) {
        // Show "Trip Completed" dialog, then route to payment
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showTripCompletedDialog(context);
        });
      }
      if (next == HomeState.bookingConfirmed) {
        Future.delayed(const Duration(milliseconds: 600), _fitMapToMarkers);
      }
    });

    // Pan camera when pickup location is geocoded
    ref.listen<LatLng?>(pickupLatLngProvider, (prev, pickup) {
      if (pickup == null) return;
      final drop = ref.read(dropLatLngProvider);
      if (drop != null) {
        Future.delayed(const Duration(milliseconds: 300), _fitMapToMarkers);
      } else {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pickup, 15));
      }
    });

    // Pan camera when drop location is geocoded
    ref.listen<LatLng?>(dropLatLngProvider, (prev, drop) {
      if (drop == null) return;
      final pickup = ref.read(pickupLatLngProvider);
      if (pickup != null) {
        Future.delayed(const Duration(milliseconds: 300), _fitMapToMarkers);
      } else {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(drop, 15));
      }
    });

    // Cash payment done — show top banner then go idle
    ref.listen<String?>(cashPaidAmountProvider, (prev, amount) {
      if (amount == null) return;
      ref.read(cashPaidAmountProvider.notifier).state = null;
      _showTopNotification(
        context,
        icon: Icons.payments_outlined,
        title: 'Please pay ₹$amount to the driver',
        subtitle: 'Thank you for choosing Pick-C!',
        duration: const Duration(seconds: 5),
      );
    });

    // Trip event notifications
    ref.listen<TripEvent>(tripEventProvider, (prev, event) {
      if (event == TripEvent.none) return;
      switch (event) {
        case TripEvent.driverAtPickup:
          _showTripSnackBar(
            context,
            icon: Icons.location_on,
            color: AppColors.statusCompleted,
            title: 'Driver has reached pickup location',
            subtitle: 'Please be ready with your cargo.',
          );
        case TripEvent.tripStarted:
          _showTripSnackBar(
            context,
            icon: Icons.local_shipping,
            color: AppColors.accentYellow,
            title: 'Trip Started',
            subtitle: 'Vehicle is on the way to delivery location.',
          );
          Future.delayed(const Duration(milliseconds: 600), _fitMapToMarkers);
        case TripEvent.vehicleAtDrop:
          _showTripSnackBar(
            context,
            icon: Icons.flag,
            color: AppColors.statusCompleted,
            title: 'Vehicle has reached drop-off location',
            subtitle: 'Please verify the delivery.',
          );
        case TripEvent.unloadingCargo:
          _showTripSnackBar(
            context,
            icon: Icons.inventory_2_outlined,
            color: AppColors.statusPending,
            title: 'Unloading in progress',
            subtitle: 'Cargo is being unloaded at the drop location.',
            duration: const Duration(seconds: 5),
          );
        case TripEvent.none:
          break;
      }
    });

    ref.listen<bool>(bookingCancelledProvider, (prev, cancelled) {
      if (!cancelled) return;
      ref.read(bookingCancelledProvider.notifier).state = false;
      _showTopNotification(
        context,
        icon: Icons.cancel_outlined,
        title: 'Booking Cancelled',
        subtitle: 'Your booking has been cancelled successfully.',
        duration: const Duration(seconds: 3),
      );
    });

    final showDriverPanel = homeState == HomeState.waitingForDriver ||
        homeState == HomeState.bookingConfirmed ||
        homeState == HomeState.tripActive;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.accentYellow),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Book Pick-C Truck',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.accentYellow),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up, color: AppColors.accentYellow),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map fills the screen
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: ref.watch(mapMarkersProvider),
            polylines: ref.watch(mapPolylinesProvider),
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),

          // ── Center pin — only shown in idle (location selection) mode ──
          if (homeState == HomeState.idle)
            IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      _pickupLocked
                          ? 'assets/images/destination2.png'
                          : 'assets/images/source2.png',
                      width: 48,
                      height: 48,
                    ),
                    // Offset so pin tip sits exactly at center
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),

          // ── Bottom address + lock/confirm bar ──
          if (homeState == HomeState.idle)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _LocationBar(
                address: _currentAddress,
                isPickupLocked: _pickupLocked,
                onLockPickup: _lockPickup,
                onConfirmDrop: _confirmDrop,
              ),
            ),

          // 3-step booking stepper — shown in selectingTrucks state
          if (homeState == HomeState.selectingTrucks)
            DraggableScrollableSheet(
              initialChildSize: 0.52,
              minChildSize: 0.52,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: const [0.52, 0.92],
              builder: (context, scrollController) =>
                  BookingStepperSheet(scrollController: scrollController),
            ),

          // Driver details / waiting panel — fixed at bottom
          if (showDriverPanel)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: const DriverDetailsWidget(key: ValueKey('driver')),
            ),

          // My location button
          Positioned(
            bottom: homeState == HomeState.idle ? 120 :
                    homeState == HomeState.selectingTrucks ? 180 : 16,
            right: 12,
            child: _myLocationButton(),
          ),
        ],
      ),
    );
  }

// ── Trip Completed dialog ─────────────────────────────────────────────────

  void _showTripCompletedDialog(BuildContext context) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundDark,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Trip Completed',
          style: AppTextStyles.titleLarge
              .copyWith(color: AppColors.accentYellow),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Trip completed successfully.\nPlease proceed for payment options.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textHint),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push(RouteNames.payment);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentYellow,
              foregroundColor: AppColors.backgroundDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(120, 44),
            ),
            child: const Text('OK',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

// ── Map helpers ───────────────────────────────────────────────────────────

  void _fitMapToMarkers() {
    if (_mapController == null) return;
    final markers = ref.read(mapMarkersProvider);
    if (markers.isEmpty) return;
    final positions = markers.map((m) => m.position).toList();
    if (positions.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(positions.first, 15),
      );
      return;
    }
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;
    for (final p in positions) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        90,
      ),
    );
  }

  void _showTripSnackBar(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    Duration duration = const Duration(seconds: 4),
  }) {
    _showTopNotification(
      context,
      icon: icon,
      title: title,
      subtitle: subtitle,
      duration: duration,
    );
  }

  OverlayEntry? _activeNotificationEntry;

  void _showTopNotification(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Dismiss any existing notification first
    _activeNotificationEntry?.remove();
    _activeNotificationEntry = null;

    final topOffset = MediaQuery.of(context).padding.top + kToolbarHeight + 20;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopNotificationBanner(
        icon: icon,
        title: title,
        subtitle: subtitle,
        topOffset: topOffset,
        duration: duration,
        onDismissed: () {
          entry.remove();
          if (_activeNotificationEntry == entry) {
            _activeNotificationEntry = null;
          }
        },
      ),
    );

    _activeNotificationEntry = entry;
    Overlay.of(context).insert(entry);
  }

  Widget _myLocationButton() {
    return GestureDetector(
      onTap: () {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation, 15),
        );
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.my_location, color: AppColors.appBlue, size: 22),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.backgroundDark,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              color: AppColors.appBlue,
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.accentYellow,
                    radius: 28,
                    child: Icon(Icons.person,
                        color: AppColors.backgroundDark, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref.watch(customerNameProvider) ?? 'Customer',
                          style: AppTextStyles.titleMedium,
                        ),
                        Text(
                          ref.watch(customerMobileProvider) ?? '',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.textHint, height: 1),
            _drawerItem(context, Icons.home, 'Home', () => context.pop()),
            _drawerItem(context, Icons.history, 'Booking History',
                () => context.push(RouteNames.bookingHistory)),
            _drawerItem(context, Icons.person, 'Profile',
                () => context.push(RouteNames.profile)),
            _drawerItem(context, Icons.credit_card, 'Rate Card',
                () => context.push(RouteNames.rateCard)),
            _drawerItem(context, Icons.people, 'Refer a Friend',
                () => context.push(RouteNames.referral)),
            _drawerItem(context, Icons.help_outline, 'Help',
                () => context.push(RouteNames.helpWebview)),
            _drawerItem(context, Icons.info_outline, 'About',
                () => context.push(RouteNames.about)),
            _drawerItem(context, Icons.description_outlined, 'Terms & Conditions',
                () => context.push(RouteNames.terms)),
            _drawerItem(context, Icons.emergency, 'Emergency',
                () => context.push(RouteNames.emergency)),
            _drawerItem(context, Icons.message_outlined, 'Send Query',
                () => context.push(RouteNames.query)),
            const Spacer(),
            _drawerItem(context, Icons.logout, 'Logout', () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go(RouteNames.login);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  ListTile _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textLight),
      title: Text(title, style: AppTextStyles.bodyMedium),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location bar — address + lock/confirm button at bottom
// ─────────────────────────────────────────────────────────────────────────────

class _LocationBar extends StatelessWidget {
  final String address;
  final bool isPickupLocked;
  final VoidCallback onLockPickup;
  final VoidCallback onConfirmDrop;

  const _LocationBar({
    required this.address,
    required this.isPickupLocked,
    required this.onLockPickup,
    required this.onConfirmDrop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, -2))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Row(
        children: [
          Image.asset(
            isPickupLocked
                ? 'assets/images/destination2.png'
                : 'assets/images/source2.png',
            width: 28,
            height: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isPickupLocked ? 'Drop Location' : 'Pickup Location',
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address.isEmpty ? 'Move map to set location...' : address,
                  style: TextStyle(
                    color: address.isEmpty ? AppColors.textHint : AppColors.textLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: address.isEmpty
                ? null
                : isPickupLocked
                    ? onConfirmDrop
                    : onLockPickup,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: address.isEmpty ? AppColors.textHint : AppColors.accentYellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPickupLocked ? Icons.check : Icons.lock,
                    color: AppColors.backgroundDark,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPickupLocked ? 'Confirm' : 'Set Pickup',
                    style: const TextStyle(
                      color: AppColors.backgroundDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top notification banner — slides down from AppBar, yellow bg + black text
// ─────────────────────────────────────────────────────────────────────────────

class _TopNotificationBanner extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double topOffset;
  final Duration duration;
  final VoidCallback onDismissed;

  const _TopNotificationBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.topOffset,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_TopNotificationBanner> createState() =>
      _TopNotificationBannerState();
}

class _TopNotificationBannerState extends State<_TopNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _ctrl.forward();

    // Auto-dismiss after duration
    Future.delayed(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topOffset,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.accentYellow,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(widget.icon,
                        color: AppColors.backgroundDark, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: AppColors.backgroundDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                color: AppColors.backgroundDark
                                    .withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.close,
                        color: AppColors.backgroundDark.withValues(alpha: 0.5),
                        size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
