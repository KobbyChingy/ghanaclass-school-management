import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  
  // Stream controller for connectivity status
  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;
  
  bool _isOnline = false;
  bool get isOnline => _isOnline;
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  ConnectivityService() {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      _updateStatus(result);
    });
  }

  void _updateStatus(List<ConnectivityResult> result) {
    final isConnected = result.any((r) => 
      r == ConnectivityResult.wifi || 
      r == ConnectivityResult.ethernet ||
      r == ConnectivityResult.mobile
    );

    if (_isOnline != isConnected) {
      _isOnline = isConnected;
      _statusController.add(_isOnline);
    }
  }

  Future<bool> checkConnectivity() async {
    final List<ConnectivityResult> result = await _connectivity.checkConnectivity();
    return result.any((r) => 
      r == ConnectivityResult.wifi || 
      r == ConnectivityResult.ethernet ||
      r == ConnectivityResult.mobile
    );
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}
