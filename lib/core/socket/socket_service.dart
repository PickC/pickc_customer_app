import 'dart:async';

/// Polling-based real-time service.
/// Android used HTTP polling every 10s (WebSocket code was commented out).
/// This matches that behavior exactly via Stream.periodic.
///
/// Future upgrade: replace Stream.periodic with WebSocketChannel
/// in this file only — no UI code changes needed (StreamProvider abstraction).
class SocketService {
  Timer? _timer;
  final StreamController<void> _controller =
      StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void startPolling(Duration interval) {
    stopPolling();
    _timer = Timer.periodic(interval, (_) {
      if (!_controller.isClosed) {
        _controller.add(null);
      }
    });
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stopPolling();
    _controller.close();
  }
}
