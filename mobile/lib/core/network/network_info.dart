import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../logging/app_logger.dart';

enum NetworkStatus {
  online,
  offline,
  slow,
  reconnecting,
  reconnected,
}

abstract class NetworkInfo {
  Future<bool> get isConnected;
  Future<bool> get isServerReachable;
  NetworkStatus get currentStatus;
  Stream<NetworkStatus> get onStatusChanged;
  ValueNotifier<NetworkStatus> get statusNotifier;
  Future<NetworkStatus> checkConnectivity();
  void setStatusForTesting(NetworkStatus status);
  void dispose();
}

typedef HostLookup = Future<List<InternetAddress>> Function(String host);

class NetworkInfoImpl implements NetworkInfo {
  final HostLookup _hostLookup;
  final Duration _probeTimeout;
  final StreamController<NetworkStatus> _controller = StreamController<NetworkStatus>.broadcast();
  final ValueNotifier<NetworkStatus> _statusNotifier = ValueNotifier<NetworkStatus>(NetworkStatus.online);
  
  Timer? _periodicTimer;
  NetworkStatus _lastReportedStatus = NetworkStatus.online;
  bool _isChecking = false;

  NetworkInfoImpl({
    HostLookup? hostLookup,
    Duration probeTimeout = const Duration(seconds: 3),
    Duration checkInterval = const Duration(seconds: 15),
    bool startMonitoring = true,
  })  : _hostLookup = hostLookup ?? InternetAddress.lookup,
        _probeTimeout = probeTimeout {
    if (startMonitoring && !kIsWeb) {
      _startPeriodicCheck(checkInterval);
    }
  }

  void _startPeriodicCheck(Duration interval) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => checkConnectivity());
  }

  @override
  NetworkStatus get currentStatus => _statusNotifier.value;

  @override
  ValueNotifier<NetworkStatus> get statusNotifier => _statusNotifier;

  @override
  Stream<NetworkStatus> get onStatusChanged => _controller.stream;

  @override
  Future<bool> get isConnected async {
    final status = await checkConnectivity();
    return status != NetworkStatus.offline;
  }

  @override
  Future<bool> get isServerReachable async {
    try {
      final stopwatch = Stopwatch()..start();
      final results = await _hostLookup('firestore.googleapis.com').timeout(_probeTimeout);
      stopwatch.stop();
      return results.isNotEmpty && results.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<NetworkStatus> checkConnectivity() async {
    if (_isChecking) return _statusNotifier.value;
    _isChecking = true;

    try {
      final stopwatch = Stopwatch()..start();
      final results = await _hostLookup('google.com').timeout(_probeTimeout);
      stopwatch.stop();

      final hasConnection = results.isNotEmpty && results.first.rawAddress.isNotEmpty;

      if (!hasConnection) {
        _updateStatus(NetworkStatus.offline);
        return NetworkStatus.offline;
      }

      // Check latency for slow/unstable connection
      final latencyMs = stopwatch.elapsedMilliseconds;
      if (latencyMs > 2500) {
        _updateStatus(NetworkStatus.slow);
        return NetworkStatus.slow;
      }

      // Check transition from offline to reconnected
      if (_lastReportedStatus == NetworkStatus.offline || _lastReportedStatus == NetworkStatus.reconnecting) {
        _updateStatus(NetworkStatus.reconnected);
        // Automatically settle to online after brief reconnected notification
        Future.delayed(const Duration(seconds: 3), () {
          if (_statusNotifier.value == NetworkStatus.reconnected) {
            _updateStatus(NetworkStatus.online);
          }
        });
        return NetworkStatus.reconnected;
      }

      _updateStatus(NetworkStatus.online);
      return NetworkStatus.online;
    } on TimeoutException {
      AppLogger.w('Network check timed out.');
      _updateStatus(NetworkStatus.offline);
      return NetworkStatus.offline;
    } on SocketException catch (e) {
      AppLogger.w('SocketException during network check: ${e.message}');
      _updateStatus(NetworkStatus.offline);
      return NetworkStatus.offline;
    } catch (e) {
      AppLogger.w('Unexpected error checking connectivity: $e');
      _updateStatus(NetworkStatus.offline);
      return NetworkStatus.offline;
    } finally {
      _isChecking = false;
    }
  }

  void _updateStatus(NetworkStatus newStatus) {
    if (_lastReportedStatus != newStatus) {
      _lastReportedStatus = newStatus;
      _statusNotifier.value = newStatus;
      if (!_controller.isClosed) {
        _controller.add(newStatus);
      }
      AppLogger.i('Network connectivity state transition: $newStatus');
    }
  }

  @override
  void setStatusForTesting(NetworkStatus status) {
    _updateStatus(status);
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _controller.close();
    _statusNotifier.dispose();
  }
}
