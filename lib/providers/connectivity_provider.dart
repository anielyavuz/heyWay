import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectivityProvider with ChangeNotifier {
  ConnectivityProvider() {
    _initialize();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _firebaseCheckTimer;
  
  bool _isConnected = true;
  bool _isFirebaseConnected = true;
  bool _isInitialized = false;

  bool get isConnected => _isConnected && _isFirebaseConnected;
  bool get isInitialized => _isInitialized;
  String get connectionStatus {
    if (!_isInitialized) return 'Checking...';
    if (!_isConnected) return 'No Internet';
    if (!_isFirebaseConnected) return 'Firebase Error';
    return 'Online';
  }

  void _initialize() async {
    // Check initial connectivity status
    try {
      final List<ConnectivityResult> connectivityResult = await _connectivity.checkConnectivity();
      _updateConnectionStatus(connectivityResult);
    } catch (e) {
      debugPrint('Error checking initial connectivity: $e');
      _isConnected = false;
    }
    
    // Check initial Firebase connectivity
    await _checkFirebaseConnectivity();
    
    _isInitialized = true;
    notifyListeners();

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (error) {
        debugPrint('Connectivity stream error: $error');
        _isConnected = false;
        notifyListeners();
      },
    );

    // Start periodic Firebase connectivity checks
    _startFirebaseConnectivityChecks();
  }

  void _updateConnectionStatus(List<ConnectivityResult> connectivityResult) {
    final wasConnected = _isConnected;
    
    // Check if any of the results indicate a connection
    _isConnected = connectivityResult.any((result) => 
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet ||
      result == ConnectivityResult.vpn
    );

    // Only notify if connection status actually changed
    if (wasConnected != _isConnected) {
      debugPrint('Connection status changed: $_isConnected');
      notifyListeners();
    }
  }

  Future<void> _checkFirebaseConnectivity() async {
    try {
      // Try to read from Firestore with a timeout
      await FirebaseFirestore.instance
          .collection('connectivity_test')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
      
      _isFirebaseConnected = true;
      debugPrint('Firebase connectivity: OK');
    } catch (e) {
      _isFirebaseConnected = false;
      debugPrint('Firebase connectivity error: $e');
    }
  }

  void _startFirebaseConnectivityChecks() {
    // Check Firebase connectivity every 30 seconds
    _firebaseCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final wasFirebaseConnected = _isFirebaseConnected;
      await _checkFirebaseConnectivity();
      
      // Only notify if Firebase connection status changed
      if (wasFirebaseConnected != _isFirebaseConnected) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _firebaseCheckTimer?.cancel();
    super.dispose();
  }
}