import 'package:signalr_netcore/signalr_client.dart';

/// Thin wrapper around the SignalR HubConnection.
/// Used by the tracking feature to receive live driver GPS updates.
class SignalRService {
  static const String hubUrl =
      'https://pickcapi-atgcb7d4afccanav.centralindia-01.azurewebsites.net/hubs/trip';

  HubConnection? _hub;

  bool get isConnected =>
      _hub?.state == HubConnectionState.Connected;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (isConnected) return;

    _hub = HubConnectionBuilder()
        .withUrl(hubUrl)
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 30000])
        .build();

    await _hub!.start();
  }

  Future<void> disconnect() async {
    await _hub?.stop();
    _hub = null;
  }

  // ── Customer subscriptions ─────────────────────────────────────────────────

  /// Subscribe to live updates for [tripId].
  Future<void> watchTrip(String tripId) async {
    if (!isConnected || tripId.isEmpty) return;
    await _hub!.invoke('WatchTrip', args: [tripId]);
  }

  /// Unsubscribe when leaving the tracking screen.
  Future<void> stopWatchingTrip(String tripId) async {
    if (_hub == null || tripId.isEmpty) return;
    try {
      await _hub!.invoke('StopWatchingTrip', args: [tripId]);
    } catch (_) {
      // Non-fatal — connection may already be closing
    }
  }

  // ── Event listeners ────────────────────────────────────────────────────────

  /// Fires when the driver sends a new GPS position.
  /// Positional args: [tripId, latitude, longitude, bearing?, speedKmh?]
  void onDriverLocationUpdated(
      void Function(String tripId, double lat, double lng, double? bearing,
              double? speedKmh)
          callback) {
    _hub?.on('ReceiveDriverLocation', (List<Object?>? args) {
      if (args == null || args.length < 3) return;
      final tripId = args[0] as String? ?? '';
      final lat = (args[1] as num).toDouble();
      final lng = (args[2] as num).toDouble();
      final bearing = args.length > 3 ? (args[3] as num?)?.toDouble() : null;
      final speed = args.length > 4 ? (args[4] as num?)?.toDouble() : null;
      callback(tripId, lat, lng, bearing, speed);
    });
  }

  /// Fires when the driver signals the trip has ended.
  void onTripEnded(void Function(String tripId) callback) {
    _hub?.on('TripEnded', (List<Object?>? args) {
      if (args == null || args.isEmpty) return;
      final tripId = args[0] as String? ?? '';
      callback(tripId);
    });
  }

  /// Clear all listeners (call before re-registering to avoid duplicates).
  void clearListeners() {
    _hub?.off('ReceiveDriverLocation');
    _hub?.off('TripEnded');
  }
}
