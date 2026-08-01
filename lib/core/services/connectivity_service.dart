import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  
  // Stream controller for connectivity status
  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;
  
  bool _isOnline = true; // Default to true (optimistic) unless proven otherwise
  bool get isOnline => _isOnline;
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _initialized = false;
  DateTime? _lastOfflineTime;

  ConnectivityService() {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    try {
      // Check initial connectivity with timeout to prevent hangs
      try {
        final result = await _connectivity.checkConnectivity().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            // If check times out, assume online (connectivity_plus may be slow)
            return [ConnectivityResult.other];
          },
        );
        _updateStatus(result);
      } catch (e) {
        // If initial check fails, assume online
        _isOnline = true;
      }

      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (result) {
          _updateStatus(result);
        },
        onError: (e) {
          // If listener encounters error, stay online (assume connectivity issue is temporary)
          _isOnline = true;
        },
      );
    } catch (e) {
      // If connectivity_plus fails to initialize, assume online (let login attempt to fail naturally)
      _isOnline = true;
    }
    _initialized = true;
  }

  void _updateStatus(List<ConnectivityResult> result) {
    // Handle empty result list - could mean connectivity check is still initializing
    if (result.isEmpty) {
      // Don't mark as offline for empty results; might be a transient issue
      return;
    }

    final hasNetworkConnection = result.any((r) => 
      r == ConnectivityResult.wifi || 
      r == ConnectivityResult.ethernet ||
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.other // Count 'other' as online (unknown connections)
    );

    if (_isOnline != hasNetworkConnection) {
      _isOnline = hasNetworkConnection;
      
      // Track when we go offline to help with debugging
      if (!_isOnline) {
        _lastOfflineTime = DateTime.now();
      }
      
      _statusController.add(_isOnline);
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final List<ConnectivityResult> result = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(seconds: 3));
      
      if (result.isEmpty) {
        // Empty result - assume online (check may not have completed)
        return true;
      }
      
      return result.any((r) => 
        r == ConnectivityResult.wifi || 
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.other
      );
    } catch (e) {
      // If check fails or times out, assume we have connectivity
      // The actual HTTP request will fail if we truly don't have network
      return true;
    }
  }

  /// Check if the backend server is actually reachable via DNS + basic connectivity
  Future<bool> isBackendReachable(String backendUrl) async {
    try {
      // Extract hostname from URL
      final uri = Uri.parse(backendUrl);
      final host = uri.host;
      
      if (host.isEmpty) return false;
      
      // Try to resolve the hostname (this tests DNS + network connectivity)
      final result = await InternetAddress.lookup(host)
        .timeout(const Duration(seconds: 5));
      
      return result.isNotEmpty;
    } catch (e) {
      // If lookup fails, backend is not reachable
      return false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}
