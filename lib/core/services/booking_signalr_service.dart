import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// SignalR wrapper for the booking lifecycle hub.
/// Separate from the trip-tracking hub (signalr_service.dart) — both can be
/// connected simultaneously during an active booking transitioning to a trip.
class BookingSignalRService {
  static const String hubUrl =
      'https://pickcapi-atgcb7d4afccanav.centralindia-01.azurewebsites.net/hubs/booking';

  HubConnection? _hub;

  bool get isConnected => _hub?.state == HubConnectionState.Connected;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// [tokenGetter] is called on every connect / reconnect attempt so the
  /// latest JWT is attached to the WebSocket handshake. May return null.
  Future<void> connect({Future<String?> Function()? tokenGetter}) async {
    if (isConnected) return;
    _hub = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: tokenGetter == null
                ? null
                : () async => (await tokenGetter()) ?? '',
          ),
        )
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 30000])
        .build();
    await _hub!.start();
  }

  Future<void> disconnect() async {
    await _hub?.stop();
    _hub = null;
  }

  // ── Subscriptions ──────────────────────────────────────────────────────────

  Future<void> watchBooking(String bookingNo) async {
    if (!isConnected || bookingNo.isEmpty) return;
    await _hub!.invoke('WatchBooking', args: [bookingNo]);
  }

  Future<void> stopWatchingBooking(String bookingNo) async {
    if (_hub == null || bookingNo.isEmpty) return;
    try {
      await _hub!.invoke('StopWatchingBooking', args: [bookingNo]);
    } catch (_) {
      // Non-fatal — connection may already be closing
    }
  }

  // ── Event listeners ────────────────────────────────────────────────────────

  /// Driver accepted the booking.
  /// Payload: { bookingNo, driverName, driverMobile, driverId, vehicleNo, otp, timestamp }
  void onBookingAccepted(void Function(BookingAcceptedEvent) callback) {
    _hub?.on('BookingAccepted', (args) {
      final data = _firstMap(args);
      if (data == null) return;
      callback(BookingAcceptedEvent(
        bookingNo: data['bookingNo']?.toString() ?? '',
        driverName: data['driverName']?.toString() ?? '',
        driverMobile: data['driverMobile']?.toString() ?? '',
        driverId: data['driverId']?.toString() ?? '',
        vehicleNo: data['vehicleNo']?.toString() ?? '',
        otp: data['otp']?.toString() ?? '',
      ));
    });
  }

  /// Driver arrived at the pickup location.
  /// Payload: { bookingNo, timestamp }
  void onDriverReachedPickup(void Function(String bookingNo) callback) {
    _hub?.on('DriverReachedPickup', (args) {
      final data = _firstMap(args);
      if (data == null) return;
      callback(data['bookingNo']?.toString() ?? '');
    });
  }

  /// Booking finished — invoice ready / proceed to payment.
  /// Payload: { bookingNo, timestamp }
  void onBookingCompleted(void Function(String bookingNo) callback) {
    _hub?.on('BookingCompleted', (args) {
      final data = _firstMap(args);
      if (data == null) return;
      callback(data['bookingNo']?.toString() ?? '');
    });
  }

  /// Driver cancelled the booking.
  /// Payload: { bookingNo, cancelledBy: "DRIVER", timestamp }
  void onBookingCancelled(void Function(String bookingNo, String cancelledBy) callback) {
    _hub?.on('BookingCancelled', (args) {
      final data = _firstMap(args);
      if (data == null) return;
      callback(
        data['bookingNo']?.toString() ?? '',
        data['cancelledBy']?.toString() ?? 'DRIVER',
      );
    });
  }

  /// Clear all listeners — call before re-registering to avoid duplicates.
  void clearListeners() {
    _hub?.off('BookingAccepted');
    _hub?.off('DriverReachedPickup');
    _hub?.off('BookingCompleted');
    _hub?.off('BookingCancelled');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Server sends events as `Clients.Caller.SendAsync("Name", new {...})`,
  /// which arrives as a single Map in args[0].
  Map<String, dynamic>? _firstMap(List<Object?>? args) {
    if (args == null || args.isEmpty) return null;
    final first = args.first;
    if (first is Map) {
      try {
        return Map<String, dynamic>.from(first);
      } catch (e) {
        debugPrint('[BookingSignalR] payload cast failed: $e');
        return null;
      }
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class BookingAcceptedEvent {
  final String bookingNo;
  final String driverName;
  final String driverMobile;
  final String driverId;
  final String vehicleNo;
  final String otp;

  const BookingAcceptedEvent({
    required this.bookingNo,
    required this.driverName,
    required this.driverMobile,
    required this.driverId,
    required this.vehicleNo,
    required this.otp,
  });
}
