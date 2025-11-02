import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for detecting device state changes (charging, screen unlock, etc.)
/// This is a comprehensive device state monitoring service for context-aware reminders
class DeviceStateService {
  static const MethodChannel _channel = MethodChannel('com.example.awarely/device_state');
  static DeviceStateService? _instance;
  
  StreamController<DeviceStateEvent>? _stateController;
  StreamSubscription? _batterySubscription;
  
  bool _isCharging = false;
  bool _wasCharging = false;
  double _batteryLevel = 0.0;
  DateTime? _lastScreenUnlock;
  
  DeviceStateService._internal();
  
  factory DeviceStateService() {
    _instance ??= DeviceStateService._internal();
    return _instance!;
  }
  
  /// Get current charging state
  bool get isCharging => _isCharging;
  
  /// Get current battery level (0.0 to 1.0)
  double get batteryLevel => _batteryLevel;
  
  /// Get last screen unlock time
  DateTime? get lastScreenUnlock => _lastScreenUnlock;
  
  /// Stream of device state events
  Stream<DeviceStateEvent> get stateStream {
    _stateController ??= StreamController<DeviceStateEvent>.broadcast();
    return _stateController!.stream;
  }
  
  /// Initialize device state monitoring
  /// Returns true if monitoring started successfully
  Future<bool> initialize() async {
    if (kDebugMode) {
      print('🔋 DeviceStateService: Initializing...');
    }
    
    try {
      // Set up method channel handler
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Check initial state
      await _checkInitialState();
      
      if (kDebugMode) {
        print('✅ DeviceStateService: Initialized successfully');
        print('   Initial charging state: $_isCharging');
        print('   Initial battery level: ${(_batteryLevel * 100).toStringAsFixed(1)}%');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ DeviceStateService: Initialization error: $e');
        print('⚠️ DeviceStateService: Some features may not work. Using fallback mode.');
      }
      return false;
    }
  }
  
  /// Check initial device state
  Future<void> _checkInitialState() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('getBatteryState');
        if (result != null) {
          _isCharging = result['isCharging'] as bool? ?? false;
          _batteryLevel = (result['batteryLevel'] as num?)?.toDouble() ?? 0.0;
          _batteryLevel = _batteryLevel / 100.0; // Convert to 0.0-1.0
          _wasCharging = _isCharging;
        }
      } else if (Platform.isIOS) {
        // iOS battery state requires native implementation
        // For now, use fallback
        _isCharging = false;
        _batteryLevel = 0.0;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ DeviceStateService: Could not get initial state: $e');
      }
    }
  }
  
  /// Handle method calls from native platform
  Future<void> _handleMethodCall(MethodCall call) async {
    if (kDebugMode) {
      print('🔋 DeviceStateService: Method call received: ${call.method}');
    }
    
    switch (call.method) {
      case 'onBatteryStateChanged':
        final args = call.arguments as Map;
        final wasCharging = _isCharging;
        _isCharging = args['isCharging'] as bool? ?? false;
        _batteryLevel = (args['batteryLevel'] as num?)?.toDouble() ?? 0.0;
        _batteryLevel = _batteryLevel / 100.0;
        
        if (kDebugMode) {
          print('🔋 DeviceStateService: Battery state changed');
          print('   Was charging: $wasCharging');
          print('   Now charging: $_isCharging');
          print('   Battery level: ${(_batteryLevel * 100).toStringAsFixed(1)}%');
        }
        
        // Emit event
        if (_stateController != null && !_stateController!.isClosed) {
          if (wasCharging != _isCharging) {
            _stateController!.add(DeviceStateEvent(
              type: _isCharging ? DeviceStateType.chargingStarted : DeviceStateType.chargingStopped,
              timestamp: DateTime.now(),
              data: {
                'isCharging': _isCharging,
                'batteryLevel': _batteryLevel,
              },
            ));
          }
        }
        
        _wasCharging = _isCharging;
        break;
        
      case 'onScreenUnlock':
        _lastScreenUnlock = DateTime.now();
        
        if (kDebugMode) {
          print('📱 DeviceStateService: Screen unlocked at ${_lastScreenUnlock}');
        }
        
        // Emit event
        if (_stateController != null && !_stateController!.isClosed) {
          _stateController!.add(DeviceStateEvent(
            type: DeviceStateType.screenUnlock,
            timestamp: _lastScreenUnlock!,
            data: {
              'lastUnlock': _lastScreenUnlock!.toIso8601String(),
            },
          ));
        }
        break;
        
      default:
        if (kDebugMode) {
          print('⚠️ DeviceStateService: Unknown method: ${call.method}');
        }
    }
  }
  
  /// Manually check charging state (useful for polling fallback)
  Future<bool> checkChargingState() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('getBatteryState');
        if (result != null) {
          final wasCharging = _isCharging;
          _isCharging = result['isCharging'] as bool? ?? false;
          _batteryLevel = (result['batteryLevel'] as num?)?.toDouble() ?? 0.0;
          _batteryLevel = _batteryLevel / 100.0;
          
          if (wasCharging != _isCharging) {
            if (kDebugMode) {
              print('🔋 DeviceStateService: Charging state changed (manual check)');
              print('   Was: $wasCharging, Now: $_isCharging');
            }
            
            if (_stateController != null && !_stateController!.isClosed) {
              _stateController!.add(DeviceStateEvent(
                type: _isCharging ? DeviceStateType.chargingStarted : DeviceStateType.chargingStopped,
                timestamp: DateTime.now(),
                data: {
                  'isCharging': _isCharging,
                  'batteryLevel': _batteryLevel,
                },
              ));
            }
          }
          
          _wasCharging = _isCharging;
          return _isCharging;
        }
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ DeviceStateService: Error checking charging state: $e');
      }
      return false;
    }
  }
  
  /// Check if device just started charging (since last check)
  bool get justStartedCharging => _isCharging && !_wasCharging;
  
  /// Check if device just stopped charging (since last check)
  bool get justStoppedCharging => !_isCharging && _wasCharging;
  
  /// Dispose resources
  void dispose() {
    _batterySubscription?.cancel();
    _stateController?.close();
    _stateController = null;
    
    if (kDebugMode) {
      print('🛑 DeviceStateService: Disposed');
    }
  }
}

/// Device state event types
enum DeviceStateType {
  chargingStarted,
  chargingStopped,
  screenUnlock,
  batteryLow,
  batteryCritical,
}

/// Device state event
class DeviceStateEvent {
  final DeviceStateType type;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  
  DeviceStateEvent({
    required this.type,
    required this.timestamp,
    this.data,
  });
  
  @override
  String toString() {
    return 'DeviceStateEvent(type: $type, time: $timestamp, data: $data)';
  }
}

