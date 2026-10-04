import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../../models/sudden_death_ws_dto.dart';

/// Contract for WebSocket communication in Sudden Death.
abstract class SuddenDeathSocketClient {
  /// Stream of server events received over WebSocket.
  Stream<WsServerEvent> get events;

  /// Whether the socket is currently connected.
  bool get isConnected;

  /// Connects to the given WebSocket URI.
  Future<void> connect(Uri uri);

  /// Sends an inbound message frame to the server.
  void send(WsInboundMessage message);

  /// Closes the connection gracefully.
  Future<void> close([int? code, String? reason]);
}

/// Standard production implementation using `dart:io` [WebSocket].
class IoSuddenDeathSocketClient implements SuddenDeathSocketClient {
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  final StreamController<WsServerEvent> _eventsController =
      StreamController<WsServerEvent>.broadcast();

  @override
  Stream<WsServerEvent> get events => _eventsController.stream;

  @override
  bool get isConnected =>
      _socket != null && _socket!.readyState == WebSocket.open;

  @override
  Future<void> connect(Uri uri) async {
    await close();

    developer.log(
      'Connecting to WebSocket: ${uri.replace(queryParameters: {...uri.queryParameters, if (uri.queryParameters.containsKey('token')) 'token': '***'})}',
      name: 'SuddenDeathSocket',
    );

    try {
      final socket = await WebSocket.connect(uri.toString());
      _socket = socket;

      _subscription = socket.listen(
        (data) {
          try {
            final rawStr = data is String
                ? data
                : utf8.decode(data as List<int>);
            final decoded = jsonDecode(rawStr);
            if (decoded is Map<String, dynamic>) {
              final event = WsServerEvent.fromJson(decoded);
              _eventsController.add(event);
            }
          } catch (e, st) {
            developer.log(
              'Error decoding WebSocket frame: $e',
              name: 'SuddenDeathSocket',
              error: e,
              stackTrace: st,
            );
          }
        },
        onError: (Object error, StackTrace st) {
          developer.log(
            'WebSocket stream error: $error',
            name: 'SuddenDeathSocket',
            error: error,
            stackTrace: st,
          );
          _eventsController.add(
            WsErrorEvent(
              WsErrorPayload(code: 'socket_error', message: error.toString()),
            ),
          );
        },
        onDone: () {
          developer.log(
            'WebSocket connection closed by server (code: ${socket.closeCode}, reason: ${socket.closeReason})',
            name: 'SuddenDeathSocket',
          );
        },
        cancelOnError: false,
      );
    } catch (e, st) {
      developer.log(
        'WebSocket connect failed: $e',
        name: 'SuddenDeathSocket',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  void send(WsInboundMessage message) {
    if (!isConnected) {
      developer.log(
        'Cannot send message: WebSocket is not open',
        name: 'SuddenDeathSocket',
      );
      return;
    }

    try {
      final jsonStr = jsonEncode(message.toJson());
      _socket!.add(jsonStr);
    } catch (e) {
      developer.log(
        'Failed to send WebSocket message: $e',
        name: 'SuddenDeathSocket',
        error: e,
      );
    }
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    await _subscription?.cancel();
    _subscription = null;

    if (_socket != null) {
      try {
        await _socket!.close(code ?? WebSocketStatus.normalClosure, reason);
      } catch (_) {}
      _socket = null;
    }
  }

  /// Disposes resources and stream controllers permanently.
  Future<void> dispose() async {
    await close();
    await _eventsController.close();
  }
}
