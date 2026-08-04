import 'dart:convert';
import 'dart:async';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../config/app_config.dart';

/// WebSocket service using stomp_dart_client with RAW WebSocket transport.
/// Connects directly to ws://host/ws (Spring's non-SockJS endpoint).
class WebSocketService {
  static String get _wsUrl => AppConfig.wsUrl;

  static StompClient? _stompClient;
  static final Map<String, Function> _listeners = {};
  static final Map<String, dynamic> _subscriptions = {};
  static String _token = '';
  static bool _isConnected = false;
  static Completer<void>? _connectionCompleter;

  /// Set authentication token
  static void setToken(String token) {
    _token = token;
  }

  /// Connect to WebSocket with STOMP over raw WebSocket
  static Future<void> connect() async {
    if (_isConnected && _stompClient != null) {
      print('✅ STOMP already connected');
      return;
    }

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      return _connectionCompleter!.future;
    }

    _connectionCompleter = Completer<void>();

    try {
      _stompClient = StompClient(
        config: StompConfig(
          url: _wsUrl,
          stompConnectHeaders: {
            'Authorization': 'Bearer $_token',
            'token': _token,
          },
          onConnect: (StompFrame frame) {
            print('✅ STOMP CONNECTED successfully!');
            _isConnected = true;
            if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
              _connectionCompleter!.complete();
            }
            _resubscribeAll();
          },
          onWebSocketError: (dynamic error) {
            print('❌ WebSocket error: $error');
            _isConnected = false;
          },
          onStompError: (StompFrame frame) {
            print('❌ STOMP error: ${frame.body}');
            _isConnected = false;
          },
          onDisconnect: (StompFrame frame) {
            print('❌ STOMP disconnected');
            _isConnected = false;
          },
          onWebSocketDone: () {
            print('❌ WebSocket closed');
            _isConnected = false;
          },
          reconnectDelay: const Duration(seconds: 5),
        ),
      );

      _stompClient!.activate();
      print('🔗 STOMP client activating via raw WebSocket...');

      await _connectionCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⚠️ STOMP connection timeout - will retry via auto-reconnect');
          throw TimeoutException('STOMP connection timeout');
        },
      );
    } catch (e) {
      print('❌ STOMP connection error: $e');
      _isConnected = false;
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(e);
      }
      rethrow;
    }
  }

  /// Re-subscribe to all active listeners after reconnect
  static void _resubscribeAll() {
    final pendingListeners = Map<String, Function>.from(_listeners);
    for (final entry in pendingListeners.entries) {
      final key = entry.key;
      final callback = entry.value;
      final destination = '/topic/$key';

      if (_stompClient != null && _isConnected) {
        final sub = _stompClient!.subscribe(
          destination: destination,
          callback: (StompFrame frame) {
            if (frame.body != null) {
              try {
                final data = jsonDecode(frame.body!);
                print('📨 STOMP message from $destination');
                callback(data);
              } catch (e) {
                print('⚠️ Error parsing STOMP message: $e');
              }
            }
          },
        );
        _subscriptions[key] = sub;
        print('✅ Re-subscribed to $destination');
      }
    }
  }

  /// Send message via STOMP (for driver location broadcast)
  static Future<void> sendMessage({
    required String destination,
    required String body,
  }) async {
    await connect();

    if (_stompClient != null && _isConnected) {
      _stompClient!.send(
        destination: destination,
        body: body,
      );
      print('✅ STOMP message sent to $destination');
    } else {
      print('⚠️ Cannot send message - not connected');
    }
  }

  /// Subscribe to ride location updates
  static Future<void> subscribeToRideLocation(String rideId, Function(Map<String, dynamic>) onUpdate) async {
    final key = 'ride/$rideId/location';
    _listeners[key] = onUpdate;

    await connect();

    if (_stompClient != null && _isConnected) {
      final sub = _stompClient!.subscribe(
        destination: '/topic/$key',
        callback: (StompFrame frame) {
          if (frame.body != null) {
            try {
              final data = jsonDecode(frame.body!);
              print('📍 Location update received for ride $rideId');
              onUpdate(data);
            } catch (e) {
              print('⚠️ Error parsing location update: $e');
            }
          }
        },
      );
      _subscriptions[key] = sub;
      print('✅ Subscribed to /topic/$key');
    }
  }

  /// Subscribe to ride status updates
  static Future<void> subscribeToRideStatus(String userId, Function(Map<String, dynamic>) onUpdate) async {
    final key = 'user/$userId/ride';
    _listeners[key] = onUpdate;

    await connect();

    if (_stompClient != null && _isConnected) {
      final sub = _stompClient!.subscribe(
        destination: '/topic/$key',
        callback: (StompFrame frame) {
          if (frame.body != null) {
            try {
              final data = jsonDecode(frame.body!);
              print('📡 Status update received for user $userId');
              onUpdate(data);
            } catch (e) {
              print('⚠️ Error parsing status update: $e');
            }
          }
        },
      );
      _subscriptions[key] = sub;
      print('✅ Subscribed to /topic/$key');
    }
  }

  /// Subscribe to driver-specific ride updates (cancellation, payment method changes, etc.)
  static Future<void> subscribeToDriverRideUpdates(String driverId, Function(Map<String, dynamic>) onUpdate) async {
    final key = 'driver/$driverId/ride';
    _listeners[key] = onUpdate;

    await connect();

    if (_stompClient != null && _isConnected) {
      final sub = _stompClient!.subscribe(
        destination: '/topic/$key',
        callback: (StompFrame frame) {
          if (frame.body != null) {
            try {
              final data = jsonDecode(frame.body!);
              print('📡 Driver ride update received for driver $driverId');
              onUpdate(data);
            } catch (e) {
              print('⚠️ Error parsing driver ride update: $e');
            }
          }
        },
      );
      _subscriptions[key] = sub;
      print('✅ Subscribed to /topic/$key');
    }
  }

  /// Subscribe to ride fare updates
  static Future<void> subscribeToRideFare(String rideId, Function(Map<String, dynamic>) onUpdate) async {
    final key = 'ride/$rideId/fare';
    _listeners[key] = onUpdate;

    await connect();

    if (_stompClient != null && _isConnected) {
      final sub = _stompClient!.subscribe(
        destination: '/topic/$key',
        callback: (StompFrame frame) {
          if (frame.body != null) {
            try {
              final data = jsonDecode(frame.body!);
              print('💰 Fare update received for ride $rideId');
              onUpdate(data);
            } catch (e) {
              print('⚠️ Error parsing fare update: $e');
            }
          }
        },
      );
      _subscriptions[key] = sub;
      print('✅ Subscribed to /topic/$key');
    }
  }

  /// Subscribe to ride chat messages
  static Future<void> subscribeToChatMessages(String rideId, Function(Map<String, dynamic>) onMessage) async {
    final key = 'ride/$rideId/chat';
    _listeners[key] = onMessage;

    await connect();

    if (_stompClient != null && _isConnected) {
      final sub = _stompClient!.subscribe(
        destination: '/topic/$key',
        callback: (StompFrame frame) {
          if (frame.body != null) {
            try {
              final data = jsonDecode(frame.body!);
              print('💬 Chat message received for ride $rideId');
              onMessage(data);
            } catch (e) {
              print('⚠️ Error parsing chat message: $e');
            }
          }
        },
      );
      _subscriptions[key] = sub;
      print('✅ Subscribed to /topic/$key');
    }
  }

  /// Unsubscribe from updates
  static void unsubscribe(String topic) {
    _subscriptions.remove(topic);
    _listeners.remove(topic);
  }

  /// Disconnect cleanly
  static void disconnect() {
    try {
      _stompClient?.deactivate();
      _stompClient = null;
      _isConnected = false;
      _subscriptions.clear();
      _listeners.clear();
      _connectionCompleter = null;
      print('🛑 STOMP disconnected');
    } catch (e) {
      print('⚠️ Error disconnecting: $e');
    }
  }

  /// Check if connected
  static bool get isConnected => _isConnected;
}
