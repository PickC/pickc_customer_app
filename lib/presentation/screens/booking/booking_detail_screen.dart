import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/booking/booking_model.dart';

class BookingDetailScreen extends StatefulWidget {
  final BookingModel booking;
  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  GoogleMapController? _mapCtrl;
  List<LatLng> _routePoints = [];

  static final _dtFmt  = DateFormat('dd-MM-yyyy  HH:mm');
  static final _dtFmt2 = DateFormat('dd-MM-yyyy HH:mm');

  BookingModel get b => widget.booking;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (b.hasCoordinates) _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final pickup = LatLng(b.latitude, b.longitude);
    final drop   = LatLng(b.toLatitude, b.toLongitude);
    try {
      final result = await PolylinePoints().getRouteBetweenCoordinates(
        googleApiKey: ApiConstants.googleMapsApiKey,
        request: PolylineRequest(
          origin:      PointLatLng(pickup.latitude, pickup.longitude),
          destination: PointLatLng(drop.latitude, drop.longitude),
          mode: TravelMode.driving,
        ),
      );
      if (!mounted) return;
      setState(() {
        _routePoints = result.points.isNotEmpty
            ? result.points.map((p) => LatLng(p.latitude, p.longitude)).toList()
            : [pickup, drop];
      });
    } catch (_) {
      if (mounted) setState(() => _routePoints = [pickup, drop]);
    }
  }

  void _fitBounds() {
    if (_mapCtrl == null || !b.hasCoordinates) return;
    final lats = [b.latitude, b.toLatitude];
    final lngs = [b.longitude, b.toLongitude];
    Future.delayed(const Duration(milliseconds: 300), () {
      _mapCtrl?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(lats.reduce(min), lngs.reduce(min)),
            northeast: LatLng(lats.reduce(max), lngs.reduce(max)),
          ),
          60,
        ),
      );
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: Text('BK#${b.bookingNo}',
            style: AppTextStyles.titleMedium),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _StatusBadge(booking: b),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Map section ──────────────────────────────────────────────────
            _buildMap(context),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Journey ────────────────────────────────────────────────
                  _buildJourney(),
                  const SizedBox(height: 16),

                  // 3. Booking info ────────────────────────────────────────────
                  _sectionHeader('Booking Info'),
                  const SizedBox(height: 8),
                  _buildInfoCard(),
                  const SizedBox(height: 16),

                  // 4. Driver/vehicle (only if confirmed) ─────────────────────
                  if (b.isConfirm) ...[
                    _sectionHeader('Driver & Vehicle'),
                    const SizedBox(height: 8),
                    _buildDriverCard(),
                    const SizedBox(height: 16),
                  ],

                  // 5. Trip timeline ───────────────────────────────────────────
                  _sectionHeader('Trip Timeline'),
                  const SizedBox(height: 8),
                  _buildTimeline(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Map section ──────────────────────────────────────────────────────────────

  Widget _buildMap(BuildContext context) {
    final mapHeight = MediaQuery.of(context).size.height * 0.40;

    if (!b.hasCoordinates) {
      return Container(
        height: mapHeight,
        color: const Color(0xFF111000),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off, color: AppColors.textHint, size: 40),
              SizedBox(height: 8),
              Text('Location unavailable',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final pickup = LatLng(b.latitude, b.longitude);
    final drop   = LatLng(b.toLatitude, b.toLongitude);

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup', snippet: b.locationFrom),
      ),
      Marker(
        markerId: const MarkerId('drop'),
        position: drop,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Destination', snippet: b.locationTo),
      ),
    };

    final polylines = _routePoints.length >= 2
        ? <Polyline>{
            Polyline(
              polylineId: const PolylineId('route'),
              points: _routePoints,
              color: const Color(0xFF1E88E5),
              width: 4,
            ),
          }
        : <Polyline>{};

    return SizedBox(
      height: mapHeight,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: pickup, zoom: 12),
        markers: markers,
        polylines: polylines,
        onMapCreated: (ctrl) {
          _mapCtrl = ctrl;
          _fitBounds();
        },
        zoomControlsEnabled: false,
        myLocationButtonEnabled: false,
      ),
    );
  }

  // ── Journey row ──────────────────────────────────────────────────────────────

  Widget _buildJourney() {
    return _SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon column
          Column(
            children: [
              const Icon(Icons.circle, color: Color(0xFF43A047), size: 12),
              Container(
                  width: 1.5, height: 28,
                  color: AppColors.textHint.withValues(alpha: 0.4)),
              const Icon(Icons.stop_rounded, color: Color(0xFFE53935), size: 12),
            ],
          ),
          const SizedBox(width: 12),
          // Addresses
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.locationFrom,
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 13)),
                const SizedBox(height: 18),
                Text(b.locationTo,
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Booking info card ─────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    final rows = <_InfoRow>[
      _InfoRow('Booking No', b.bookingNo),
      if (b.bookingDate != null)
        _InfoRow('Booking Date', _dtFmt2.format(b.bookingDate!)),
      if (b.requiredDate != null)
        _InfoRow('Required Date', _dtFmt2.format(b.requiredDate!)),
      _InfoRow('Vehicle Type',  b.vehicleTypeName  ?? '—'),
      _InfoRow('Vehicle Group', b.vehicleGroupName ?? '—'),
      _InfoRow('Cargo Type',    b.cargoType        ?? '—'),
      if (b.cargoDescription?.isNotEmpty == true)
        _InfoRow('Cargo Description', b.cargoDescription!),
      _InfoRow('Payload', '${b.payLoad ?? '0'} kg'),
      _InfoRow('Loading/Unloading', b.loadingLabel),
      _InfoRow('Receiver Mobile', b.receiverMobileNo ?? '—',
          tappable: b.receiverMobileNo?.isNotEmpty == true),
      if (b.remarks?.isNotEmpty == true)
        _InfoRow('Remarks', b.remarks!),
    ];

    return _SectionCard(
      child: Column(
        children: rows
            .asMap()
            .entries
            .map((e) => _buildInfoRow(e.value, isLast: e.key == rows.length - 1))
            .toList(),
      ),
    );
  }

  Widget _buildInfoRow(_InfoRow row, {required bool isLast}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(row.label,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint, fontSize: 12)),
              ),
              Expanded(
                child: row.tappable
                    ? GestureDetector(
                        onTap: () =>
                            launchUrl(Uri.parse('tel:${row.value}')),
                        child: Text(
                          row.value,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.accentYellow,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.accentYellow,
                          ),
                        ),
                      )
                    : Text(row.value,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textLight, fontSize: 12)),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
              height: 1,
              color: AppColors.textHint.withValues(alpha: 0.12)),
      ],
    );
  }

  // ── Driver card ───────────────────────────────────────────────────────────────

  Widget _buildDriverCard() {
    return _SectionCard(
      child: Column(
        children: [
          _buildInfoRow(_InfoRow('Driver ID',    b.driverID  ?? '—'), isLast: false),
          _buildInfoRow(_InfoRow('Vehicle No',   b.vehicleNo ?? '—'), isLast: false),
          _buildInfoRow(
            _InfoRow('Confirmed At',
                b.confirmDate != null ? _dtFmt2.format(b.confirmDate!) : '—'),
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ── Trip timeline ─────────────────────────────────────────────────────────────

  Widget _buildTimeline() {
    final steps = <_TimelineStep>[
      _TimelineStep(
        label: 'Booking Placed',
        dt: b.bookingDate,
        done: true,
      ),
      if (b.isConfirm)
        _TimelineStep(label: 'Confirmed', dt: b.confirmDate, done: true),
      if (b.isReachPickUp)
        _TimelineStep(
            label: 'Driver at Pickup', dt: b.pickupReachDateTime, done: true),
      if (b.isReachPickUp)
        _TimelineStep(label: 'Picked Up / En Route', dt: null, done: true),
      if (b.isReachDestination)
        _TimelineStep(
            label: 'Reached Destination',
            dt: b.destinationReachDateTime,
            done: true),
      if (b.isComplete)
        _TimelineStep(label: 'Completed', dt: b.completeTime, done: true),
      if (b.isCancel)
        _TimelineStep(
            label: 'Cancelled',
            dt: b.cancelTime,
            done: false,
            isCancelled: true),
      if (b.isCancelByDriver)
        _TimelineStep(
            label: 'Cancelled by Driver',
            dt: b.driverCancelDateTime,
            done: false,
            isCancelled: true),
    ];

    return _SectionCard(
      child: Column(
        children: steps.asMap().entries.map((e) {
          final isLast = e.key == steps.length - 1;
          return _buildTimelineStep(e.value, isLast: isLast);
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineStep(_TimelineStep step, {required bool isLast}) {
    final iconColor = step.isCancelled
        ? const Color(0xFFE53935)
        : step.done
            ? const Color(0xFF43A047)
            : AppColors.textHint;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + connector
          Column(
            children: [
              Icon(
                step.isCancelled
                    ? Icons.cancel_outlined
                    : step.done
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                color: iconColor,
                size: 18,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: AppColors.textHint.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Label + timestamp
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    step.label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: step.isCancelled
                          ? const Color(0xFFE53935)
                          : AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                  if (step.dt != null)
                    Text(
                      _dtFmt.format(step.dt!),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint,
                        fontSize: 11,
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

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Text(
        title,
        style: AppTextStyles.titleMedium.copyWith(
          color: AppColors.accentYellow,
          fontSize: 13,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final BookingModel booking;
  const _StatusBadge({required this.booking});

  @override
  Widget build(BuildContext context) {
    final c = booking.statusColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.7), width: 0.8),
      ),
      child: Text(
        booking.statusLabel,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1500),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.textHint.withValues(alpha: 0.18), width: 0.8),
        ),
        child: child,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Data holders
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow {
  final String label;
  final String value;
  final bool tappable;
  const _InfoRow(this.label, this.value, {this.tappable = false});
}

class _TimelineStep {
  final String label;
  final DateTime? dt;
  final bool done;
  final bool isCancelled;
  const _TimelineStep({
    required this.label,
    required this.dt,
    required this.done,
    this.isCancelled = false,
  });
}
