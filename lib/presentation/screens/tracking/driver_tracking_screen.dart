import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/tracking_provider.dart';

class DriverTrackingScreen extends ConsumerStatefulWidget {
  final String tripId;
  final LatLng pickupLatLng;
  final LatLng dropLatLng;

  const DriverTrackingScreen({
    super.key,
    required this.tripId,
    required this.pickupLatLng,
    required this.dropLatLng,
  });

  @override
  ConsumerState<DriverTrackingScreen> createState() =>
      _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends ConsumerState<DriverTrackingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  // ── Map ───────────────────────────────────────────────────────────────────
  final Completer<GoogleMapController> _mapCompleter = Completer();
  BitmapDescriptor? _truckIcon;

  // ── Animation ─────────────────────────────────────────────────────────────
  // Each new GPS update triggers a 3-second lerp from _fromPos → _toPos.
  // _displayPos is what actually moves the marker on-screen.
  late AnimationController _moveCtrl;
  LatLng _fromPos = const LatLng(0, 0);
  LatLng _toPos = const LatLng(0, 0);
  LatLng _displayPos = const LatLng(0, 0);
  double _bearing = 0;
  bool _hasFirstFix = false;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _tripEnded = false;

  // ── Fixed markers ─────────────────────────────────────────────────────────
  late final Set<Marker> _staticMarkers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimation();
    _loadTruckIcon();
    _setupStaticMarkers();
    // Start SignalR after first frame so provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trackingProvider.notifier).startTracking(widget.tripId);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _moveCtrl.dispose();
    ref.read(trackingProvider.notifier).stopTracking();
    super.dispose();
  }

  // ── App lifecycle — pause animation in background to save battery ─────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _moveCtrl.stop();
    } else if (state == AppLifecycleState.resumed && !_tripEnded) {
      _moveCtrl.forward();
    }
  }

  // ── Setup ──────────────────────────────────────────────────────────────────

  void _setupAnimation() {
    // 3-second duration matches the SignalR push interval.
    // Linear curve = constant speed between two GPS points.
    _moveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..addListener(_onAnimationTick);
  }

  Future<void> _loadTruckIcon() async {
    final icon = await BitmapDescriptor.asset(
      const ImageConfiguration(devicePixelRatio: 2.5, size: Size(48, 48)),
      'assets/trucks/mini_opened_truck.png',
    );
    if (mounted) setState(() => _truckIcon = icon);
  }

  void _setupStaticMarkers() {
    _staticMarkers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup'),
      ),
      Marker(
        markerId: const MarkerId('drop'),
        position: widget.dropLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Drop-off'),
      ),
    };
  }

  // ── Animation tick — fires ~60fps while controller is running ─────────────

  void _onAnimationTick() {
    if (!mounted) return;
    final t = _moveCtrl.value;
    setState(() {
      _displayPos = LatLng(
        _lerp(_fromPos.latitude, _toPos.latitude, t),
        _lerp(_fromPos.longitude, _toPos.longitude, t),
      );
    });
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  // ── Called when provider delivers a new GPS position ──────────────────────

  void _onNewPosition(LatLng newPos, double bearing) {
    // Start the animation from wherever the marker visually is *right now*
    _fromPos = _displayPos.latitude == 0 ? newPos : _displayPos;
    _toPos = newPos;
    _bearing = bearing;
    _moveCtrl.forward(from: 0);

    // Move camera to target position immediately (camera animates independently)
    _mapCompleter.future.then((ctrl) {
      ctrl.animateCamera(CameraUpdate.newLatLng(newPos));
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Listen for state changes from the tracking notifier
    ref.listen<TrackingState>(trackingProvider, (prev, next) {
      if (next is TrackingActive) {
        if (!_hasFirstFix) {
          // Snap to first position, then start animating on subsequent updates
          _hasFirstFix = true;
          _fromPos = next.position;
          _toPos = next.position;
          setState(() => _displayPos = next.position);
          _mapCompleter.future.then((ctrl) {
            ctrl.animateCamera(
                CameraUpdate.newLatLngZoom(next.position, 16));
          });
          return;
        }
        _onNewPosition(next.position, next.bearing);
      } else if (next is TrackingCompleted) {
        setState(() => _tripEnded = true);
        _moveCtrl.stop();
        _showTripEndedDialog();
      }
    });

    final allMarkers = <Marker>{
      ..._staticMarkers,
      if (_hasFirstFix)
        Marker(
          markerId: const MarkerId('driver'),
          position: _displayPos,
          rotation: _bearing,
          anchor: const Offset(0.5, 0.5),
          flat: true, // rotates with the map bearing
          icon: _truckIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueYellow),
        ),
    };

    final trackingState = ref.watch(trackingProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        title: Text(
          'Live Tracking',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.accentYellow),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.accentYellow),
      ),
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.pickupLatLng,
              zoom: 15,
            ),
            onMapCreated: (ctrl) {
              if (!_mapCompleter.isCompleted) _mapCompleter.complete(ctrl);
            },
            markers: allMarkers,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── Loading overlay ───────────────────────────────────────────────
          if (trackingState is TrackingLoading)
            _buildLoadingOverlay(),

          // ── Error overlay ─────────────────────────────────────────────────
          if (trackingState is TrackingError)
            _buildErrorBanner(trackingState.message),

          // ── Trip Ended banner ─────────────────────────────────────────────
          if (_tripEnded)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _buildTripEndedBanner(),
            ),

          // ── Bottom status card ────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStatusCard(trackingState),
          ),
        ],
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    return Container(
      color: AppColors.backgroundDark.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.accentYellow),
            const SizedBox(height: 16),
            Text(
              'Connecting to driver...',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.statusCancelled,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => ref
                  .read(trackingProvider.notifier)
                  .startTracking(widget.tripId),
              child: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripEndedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.statusCompleted,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline,
              color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(
            'Trip Completed!',
            style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(TrackingState trackingState) {
    String statusText = 'Waiting for driver location...';
    String? speedText;

    if (trackingState is TrackingActive) {
      statusText = 'Driver is on the way';
      if (trackingState.speedKmh != null && trackingState.speedKmh! > 0) {
        speedText = '${trackingState.speedKmh!.round()} km/h';
      }
    } else if (_tripEnded) {
      statusText = 'Driver has reached the destination';
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Truck icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentYellow.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping,
                color: AppColors.accentYellow, size: 24),
          ),
          const SizedBox(width: 14),

          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(statusText, style: AppTextStyles.bodyMedium),
                if (speedText != null) ...[
                  const SizedBox(height: 2),
                  Text(speedText,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.accentYellow)),
                ],
              ],
            ),
          ),

          // Live indicator dot
          if (!_tripEnded)
            _LiveDot(),
        ],
      ),
    );
  }

  void _showTripEndedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundDark,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Trip Completed',
          style: AppTextStyles.titleLarge
              .copyWith(color: AppColors.accentYellow),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Your driver has reached the destination.',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Live indicator — pulsing yellow dot shown while tracking is active
// ─────────────────────────────────────────────────────────────────────────────

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _pulse,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.accentYellow,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text('LIVE',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.accentYellow,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            )),
      ],
    );
  }
}
