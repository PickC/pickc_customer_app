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

  // ── Customer subscriptions ─────────────────────────────────────────────────

  Future<void> watchTrip(String tripId) async {
    if (!isConnected || tripId.isEmpty) return;
    await _hub!.invoke('WatchTrip', args: [tripId]);
  }

  Future<void> stopWatchingTrip(String tripId) async {
    if (_hub == null || tripId.isEmpty) return;
    try {
      await _hub!.invoke('StopWatchingTrip', args: [tripId]);
    } catch (_) {
      // Non-fatal — connection may already be closing
    }
  }

  // ── Event listeners ────────────────────────────────────────────────────────

  /// Driver GPS update. Listens for both event names + both payload shapes:
  ///   - new spec:    object { tripId, latitude, longitude, bearing, speedKmh, timestamp }
  ///                  on 'DriverLocationUpdated'
  ///   - legacy/driver-app: positional [tripId, lat, lng, bearing, speedKmh]
  ///                  on 'ReceiveDriverLocation'
  void onDriverLocationUpdated(
      void Function(String tripId, double lat, double lng, double? bearing,
              double? speedKmh)
          callback) {
    void parse(List<Object?>? args) {
      if (args == null || args.isEmpty) return;
      final first = args.first;

      // Object payload (new spec)
      if (first is Map) {
        final m = Map<String, dynamic>.from(first);
        final tripId = m['tripId']?.toString() ?? '';
        final lat = (m['latitude']  as num?)?.toDouble();
        final lng = (m['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) return;
        callback(
          tripId,
          lat,
          lng,
          (m['bearing']  as num?)?.toDouble(),
          (m['speedKmh'] as num?)?.toDouble(),
        );
        return;
      }

      // Positional args (legacy / driver-app format)
      if (args.length >= 3) {
        final tripId = args[0] as String? ?? '';
        final lat = (args[1] as num?)?.toDouble();
        final lng = (args[2] as num?)?.toDouble();
        if (lat == null || lng == null) return;
        callback(
          tripId,
          lat,
          lng,
          args.length > 3 ? (args[3] as num?)?.toDouble() : null,
          args.length > 4 ? (args[4] as num?)?.toDouble() : null,
        );
      }
    }

    _hub?.on('DriverLocationUpdated', parse);  // new spec
    _hub?.on('ReceiveDriverLocation', parse);  // legacy
  }

  /// Trip ended. Handles both object {tripId, ...} and positional [tripId].
  void onTripEnded(void Function(String tripId) callback) {
    void parse(List<Object?>? args) {
      if (args == null || args.isEmpty) return;
      final first = args.first;
      if (first is Map) {
        final m = Map<String, dynamic>.from(first);
        callback(m['tripId']?.toString() ?? '');
        return;
      }
      callback(first as String? ?? '');
    }

    _hub?.on('TripEnded', parse);
  }

  /// Clear all listeners (call before re-registering to avoid duplicates).
  void clearListeners() {
    _hub?.off('DriverLocationUpdated');
    _hub?.off('ReceiveDriverLocation');
    _hub?.off('TripEnded');
  }
}
