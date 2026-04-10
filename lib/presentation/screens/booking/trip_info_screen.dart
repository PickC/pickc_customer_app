import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Post-trip summary screen.
/// Pass via GoRouter extra:
/// {
///   'driverName':   String,
///   'driverId':     String,
///   'vehicleType':  String,       // e.g. 'Mini - Open Truck'
///   'vehicleNo':    String,
///   'totalKm':      double,
///   'totalMinutes': int,
///   'pickupAddress': String,
///   'pickupTime':   String,       // formatted e.g. '05:55 PM'
///   'dropAddress':  String,
///   'dropTime':     String,
///   'pickupLat':    double,
///   'pickupLng':    double,
///   'dropLat':      double,
///   'dropLng':      double,
/// }
class TripInfoScreen extends StatefulWidget {
  final Map<String, dynamic> tripData;

  const TripInfoScreen({super.key, required this.tripData});

  @override
  State<TripInfoScreen> createState() => _TripInfoScreenState();
}

class _TripInfoScreenState extends State<TripInfoScreen> {
  GoogleMapController? _mapController;

  String get _driverName => widget.tripData['driverName'] ?? 'Driver';
  String get _driverId => widget.tripData['driverId'] ?? '';
  String get _vehicleType => widget.tripData['vehicleType'] ?? '';
  String get _vehicleNo => widget.tripData['vehicleNo'] ?? '';
  double get _totalKm =>
      (widget.tripData['totalKm'] as num?)?.toDouble() ?? 0.0;
  int get _totalMins => (widget.tripData['totalMinutes'] as num?)?.toInt() ?? 0;
  String get _pickupAddress => widget.tripData['pickupAddress'] ?? '';
  String get _pickupTime => widget.tripData['pickupTime'] ?? '';
  String get _dropAddress => widget.tripData['dropAddress'] ?? '';
  String get _dropTime => widget.tripData['dropTime'] ?? '';

  LatLng? get _pickupLatLng {
    final lat = (widget.tripData['pickupLat'] as num?)?.toDouble();
    final lng = (widget.tripData['pickupLng'] as num?)?.toDouble();
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null;
  }

  LatLng? get _dropLatLng {
    final lat = (widget.tripData['dropLat'] as num?)?.toDouble();
    final lng = (widget.tripData['dropLng'] as num?)?.toDouble();
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null;
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    final pickup = _pickupLatLng;
    final drop = _dropLatLng;
    if (pickup != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
    if (drop != null) {
      markers.add(Marker(
        markerId: const MarkerId('drop'),
        position: drop,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
    return markers;
  }

  CameraPosition get _initialCamera {
    final pickup = _pickupLatLng;
    if (pickup != null) {
      return CameraPosition(target: pickup, zoom: 12);
    }
    return const CameraPosition(
        target: LatLng(17.385044, 78.486671), zoom: 12);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Trip Summary'),
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.home),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Stats row ──────────────────────────────────────────────
            Row(
              children: [
                _StatChip(
                  icon: Icons.route_outlined,
                  label: 'Distance',
                  value: '${_totalKm.toStringAsFixed(2)} km',
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  value: '$_totalMins mins',
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.local_shipping_outlined,
                  label: 'Vehicle',
                  value: _vehicleType.split(' ').first,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Driver info card ───────────────────────────────────────
            _SectionCard(
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.appBlue,
                    child: Icon(Icons.person,
                        color: AppColors.textLight, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver : $_driverName',
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Driver ID : $_driverId',
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _vehicleType,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.accentYellow,
                          ),
                        ),
                        if (_vehicleNo.isNotEmpty)
                          Text(
                            'Veh No. $_vehicleNo',
                            style: AppTextStyles.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Route timeline ─────────────────────────────────────────
            Text('Trip Info', style: AppTextStyles.titleMedium),
            const SizedBox(height: 10),
            _SectionCard(
              child: Column(
                children: [
                  _RouteStop(
                    flagColor: const Color(0xFF2E7D32),
                    time: _pickupTime,
                    address: _pickupAddress,
                    isFirst: true,
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 9),
                    child: Column(
                      children: List.generate(
                        3,
                        (_) => Container(
                          width: 2,
                          height: 6,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: AppColors.textHint.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _RouteStop(
                    flagColor: AppColors.statusCancelled,
                    time: _dropTime,
                    address: _dropAddress,
                    isFirst: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Note: Trip start and end time includes truck (start/end) waiting time',
              style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 16),

            // ── Map thumbnail ──────────────────────────────────────────
            if (_pickupLatLng != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 200,
                  child: GoogleMap(
                    initialCameraPosition: _initialCamera,
                    markers: _markers,
                    onMapCreated: (c) {
                      _mapController = c;
                      if (_pickupLatLng != null && _dropLatLng != null) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngBounds(
                              LatLngBounds(
                                southwest: LatLng(
                                  [_pickupLatLng!.latitude, _dropLatLng!.latitude].reduce((a, b) => a < b ? a : b),
                                  [_pickupLatLng!.longitude, _dropLatLng!.longitude].reduce((a, b) => a < b ? a : b),
                                ),
                                northeast: LatLng(
                                  [_pickupLatLng!.latitude, _dropLatLng!.latitude].reduce((a, b) => a > b ? a : b),
                                  [_pickupLatLng!.longitude, _dropLatLng!.longitude].reduce((a, b) => a > b ? a : b),
                                ),
                              ),
                              60,
                            ),
                          );
                        });
                      }
                    },
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    myLocationButtonEnabled: false,
                    liteModeEnabled: true,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ── Thank You banner ───────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accentYellow.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.thumb_up_alt_outlined,
                      color: AppColors.accentYellow, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Thank You for using Pick-C services!',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.accentYellow,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'See you soon.',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Back to Home ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => context.go(RouteNames.home),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentYellow,
                  foregroundColor: AppColors.backgroundDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text('BACK TO HOME',
                    style: AppTextStyles.labelButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.accentYellow.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.accentYellow.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accentYellow, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.accentYellow, fontSize: 13),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1800),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.textHint.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }
}

// ── Route stop row ────────────────────────────────────────────────────────────

class _RouteStop extends StatelessWidget {
  final Color flagColor;
  final String time;
  final String address;
  final bool isFirst;

  const _RouteStop({
    required this.flagColor,
    required this.time,
    required this.address,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.flag, color: flagColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (time.isNotEmpty)
                Text(
                  time,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.accentYellow,
                    fontSize: 11,
                  ),
                ),
              Text(address, style: AppTextStyles.bodyMedium.copyWith(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
