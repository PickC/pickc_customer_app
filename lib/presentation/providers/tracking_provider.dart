import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/services/signalr_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State — sealed class (mirrors BLoC state pattern)
// ─────────────────────────────────────────────────────────────────────────────

sealed class TrackingState {
  const TrackingState();
}

/// Connecting to SignalR / waiting for first GPS fix.
class TrackingLoading extends TrackingState {
  const TrackingLoading();
}

/// Live tracking — driver position received.
class TrackingActive extends TrackingState {
  final String tripId;
  final LatLng position;
  final double bearing; // degrees 0–360, 0 = north
  final double? speedKmh;

  const TrackingActive({
    required this.tripId,
    required this.position,
    required this.bearing,
    this.speedKmh,
  });

  TrackingActive copyWith({
    LatLng? position,
    double? bearing,
    double? speedKmh,
  }) =>
      TrackingActive(
        tripId: tripId,
        position: position ?? this.position,
        bearing: bearing ?? this.bearing,
        speedKmh: speedKmh ?? this.speedKmh,
      );
}

/// Driver sent "TripEnded" — tracking is over.
class TrackingCompleted extends TrackingState {
  final String tripId;
  const TrackingCompleted({required this.tripId});
}

/// SignalR connection or other error.
class TrackingError extends TrackingState {
  final String message;
  const TrackingError(this.message);
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// AutoDispose so the SignalR connection is torn down as soon as the
/// tracking screen is popped.
final trackingProvider =
    AutoDisposeNotifierProvider<TrackingNotifier, TrackingState>(
  TrackingNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class TrackingNotifier extends AutoDisposeNotifier<TrackingState> {
  final _signalR = SignalRService();
  String _currentTripId = '';

  @override
  TrackingState build() => const TrackingLoading();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Connect to SignalR and start watching [tripId].
  Future<void> startTracking(String tripId) async {
    _currentTripId = tripId;
    state = const TrackingLoading();

    try {
      await _signalR.connect();
      _registerListeners();
      await _signalR.watchTrip(tripId);
    } catch (e) {
      state = TrackingError('Connection failed: $e');
    }
  }

  /// Unsubscribe and disconnect — called from screen dispose.
  Future<void> stopTracking() async {
    _signalR.clearListeners();
    await _signalR.stopWatchingTrip(_currentTripId);
    await _signalR.disconnect();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _registerListeners() {
    _signalR.clearListeners(); // prevent duplicates on reconnect

    _signalR.onDriverLocationUpdated((tripId, lat, lng, bearing, speedKmh) {
      if (tripId != _currentTripId) return;

      final newPos = LatLng(lat, lng);
      final current = state;

      if (current is TrackingActive) {
        if (_distanceMeters(current.position, newPos) < 2) return;
        state = current.copyWith(
          position: newPos,
          bearing: bearing ?? current.bearing,
          speedKmh: speedKmh,
        );
      } else {
        // First location fix — transition out of Loading
        state = TrackingActive(
          tripId: tripId,
          position: newPos,
          bearing: bearing ?? 0,
          speedKmh: speedKmh,
        );
      }
    });

    _signalR.onTripEnded((tripId) {
      if (tripId != _currentTripId) return;
      state = TrackingCompleted(tripId: tripId);
    });
  }

  /// Haversine distance in metres between two LatLng points.
  double _distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _toRad(double deg) => deg * math.pi / 180;
}
