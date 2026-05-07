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
import 'booking_form_widget.dart';
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
  bool _isReverseGeocoding = false;
  bool _isProgrammaticMove = false; // suppress geocode when map pans from input

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(homeNotifierProvider.notifier);
      // If a booking was in progress before the app closed, restore it.
      // Skip the normal GPS init in that case — we already have coordinates.
      final restored = await notifier.restoreActiveBookingIfAny();
      if (!restored) {
        notifier.startPolling();
        notifier.startAvailableDriversPolling();
        _initLocation();
      }
    });
  }

  Future<void> _initLocation() async {
    // Always start with pickup field active — source.png pin shows by default
    ref.read(activeLocationFieldProvider.notifier).state = true;
    // Clear any stale addresses from a previous session
    ref.read(pickupAddressProvider.notifier).state = '';
    ref.read(dropAddressProvider.notifier).state = '';
    ref.read(pickupLatLngProvider.notifier).state = null;
    ref.read(dropLatLngProvider.notifier).state = null;
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
        _isProgrammaticMove = true;
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
        // Auto-fill pickup with current GPS location.
        // Keep activeLocationFieldProvider = true (source.png pin stays)
        // so the user sees the green pickup pin by default.
        // It switches to destination.png only when the user locks pickup.
        await _reverseGeocode(latLng);
      }
    } catch (_) {}
  }

  void _onCameraMove(CameraPosition pos) {
    _mapCenter = pos.target;
  }

  Future<void> _onCameraIdle() async {
    // Skip if the camera moved because user selected from input box
    if (_isProgrammaticMove) {
      _isProgrammaticMove = false;
      return;
    }
    final center = _mapCenter;
    if (center == null) return;
    if (ref.read(homeNotifierProvider) != HomeState.idle) return;
    await _reverseGeocode(center);
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
      if (results.isEmpty || !mounted) return;
      final address = results[0]['formatted_address'] as String? ?? '';
      // Write to whichever field is currently active
      final isPickup = ref.read(activeLocationFieldProvider);
      if (isPickup) {
        ref.read(pickupAddressProvider.notifier).state = address;
        ref.read(pickupLatLngProvider.notifier).state = pos;
      } else {
        ref.read(dropAddressProvider.notifier).state = address;
        ref.read(dropLatLngProvider.notifier).state = pos;
      }
    } catch (_) {
    } finally {
      _isReverseGeocoding = false;
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showTripCompletedDialog(context);
        });
      }
      if (next == HomeState.waitingForDriver) {
        Future.delayed(const Duration(milliseconds: 800), _fitMapToMarkers);
      }
      if (next == HomeState.bookingConfirmed) {
        Future.delayed(const Duration(milliseconds: 600), _fitMapToMarkers);
      }
      // After cancellation or exit, re-acquire GPS and snap map to current location.
      // Excludes idle→idle and selectingTrucks→idle (user just unlocked a field).
      if (next == HomeState.idle &&
          prev != null &&
          prev != HomeState.idle &&
          prev != HomeState.selectingTrucks) {
        Future.delayed(const Duration(milliseconds: 300), _initLocation);
      }
    });

    // Pan to current GPS location when user unlocks a location field
    ref.listen<int>(panToMyLocationProvider, (prev, _) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation, 15),
      );
    });

    // Pan camera when pickup location is set from input box
    ref.listen<LatLng?>(pickupLatLngProvider, (prev, pickup) {
      if (pickup == null || pickup == prev) return;
      _isProgrammaticMove = true;
      final drop = ref.read(dropLatLngProvider);
      if (drop != null) {
        Future.delayed(const Duration(milliseconds: 300), _fitMapToMarkers);
      } else {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pickup, 15));
      }
    });

    // Pan camera when drop location is set from input box
    ref.listen<LatLng?>(dropLatLngProvider, (prev, drop) {
      if (drop == null || drop == prev) return;
      _isProgrammaticMove = true;
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

    ref.listen<String?>(bookingErrorProvider, (prev, error) {
      if (error == null) return;
      ref.read(bookingErrorProvider.notifier).state = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
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

    return PopScope(
      // Prevent accidental app exit while booking is in progress
      canPop: homeState != HomeState.waitingForDriver,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && homeState == HomeState.waitingForDriver) {
          _showAppCloseWarningDialog(context);
        }
      },
      child: Scaffold(
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

          // ── Uber-style center pin ──
          // Always in the Stack so BookingFormWidget below stays at a fixed index.
          // Invisible outside idle to avoid interfering with other states.
          IgnorePointer(
            child: Visibility(
              visible: homeState == HomeState.idle,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      ref.watch(activeLocationFieldProvider)
                          ? 'assets/images/source.png'
                          : 'assets/images/destination.png',
                      width: 48,
                      height: 48,
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),

          // ── Pickup / Drop input boxes overlaid at top of map ──
          // Always in the Stack (maintainState) so _pickupCtrl / _dropCtrl text
          // and locked state survive the idle → selectingTrucks transition.
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Visibility(
              visible: homeState == HomeState.idle ||
                  homeState == HomeState.selectingTrucks,
              maintainState: true,
              child: const BookingFormWidget(key: ValueKey('booking_form')),
            ),
          ),

          // 3-step booking stepper — shown in selectingTrucks state
          if (homeState == HomeState.selectingTrucks)
            DraggableScrollableSheet(
              initialChildSize: 0.50,
              minChildSize: 0.35,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: const [0.35, 0.50, 0.92],
              builder: (context, scrollController) =>
                  BookingStepperSheet(scrollController: scrollController),
            ),

          // Driver details / waiting panel — fixed at bottom.
          // SafeArea(top: false) pushes content above the system nav bar.
          if (showDriverPanel)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                child: const DriverDetailsWidget(key: ValueKey('driver')),
              ),
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
      ), // closes PopScope child (Scaffold)
    ); // closes PopScope
  }

// ── App-close warning dialog ──────────────────────────────────────────────

  void _showAppCloseWarningDialog(BuildContext context) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.accentYellow, width: 1),
        ),
        title: Text(
          'Cancel Booking?',
          style: AppTextStyles.titleLarge
              .copyWith(color: AppColors.accentYellow),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Your booking is active and waiting for a truck.\n\n'
          'If you go back now, the booking will be cancelled.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textHint),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentYellow,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
            ),
            child: const Text('No, Stay',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(homeNotifierProvider.notifier)
                  .deleteBookingOnExit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusCancelled,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
            ),
            child: const Text('Yes, Cancel',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.backgroundDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.accentYellow, width: 1),
                  ),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(color: AppColors.accentYellow, fontWeight: FontWeight.bold),
                  ),
                  content: const Text(
                    'Are you sure you want to log out?',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textHint)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentYellow,
                        foregroundColor: AppColors.backgroundDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ref.read(authNotifierProvider.notifier).logout();
                if (context.mounted) context.go(RouteNames.login);
              }
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
