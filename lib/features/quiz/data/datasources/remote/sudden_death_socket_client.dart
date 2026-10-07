import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';

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

  void _debugLog(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    developer.log(
      message,
      name: 'SuddenDeathSocket',
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  Future<void> connect(Uri uri) async {
    await close();

    _debugLog(
      '[SD] ws connecting: ${uri.replace(queryParameters: {...uri.queryParameters, if (uri.queryParameters.containsKey('token')) 'token': '***'})}',
    );

    try {
      final socket = await WebSocket.connect(uri.toString());
      _socket = socket;
      _debugLog('[SD] ws connected (HTTP 101)');

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
            _debugLog(
              '[SD] invalid WebSocket frame: $e',
              error: e,
              stackTrace: st,
            );
          }
        },
        onDone: () {
          if (identical(_socket, socket)) {
            _socket = null;
          }
          final reason = socket.closeReason?.trim();
          final detail = reason == null || reason.isEmpty
              ? 'code ${socket.closeCode ?? 'unknown'}'
              : 'code ${socket.closeCode ?? 'unknown'}, $reason';
          _debugLog('[SD] socket disconnected: $detail');
          if (!_eventsController.isClosed) {
            _eventsController.add(
              WsErrorEvent(
                WsErrorPayload(
                  code: 'socket_closed',
                  message: 'The live game connection closed ($detail).',
                ),
              ),
            );
          }
        },
        onError: (Object error, StackTrace st) {
          if (identical(_socket, socket)) {
            _socket = null;
          }
          unawaited(socket.close());
          _debugLog('[SD] socket error: $error', error: error, stackTrace: st);
          if (!_eventsController.isClosed) {
            _eventsController.add(
              WsErrorEvent(
                WsErrorPayload(code: 'socket_error', message: error.toString()),
              ),
            );
          }
        },
        cancelOnError: true,
      );
    } catch (e, st) {
      _socket = null;
      _debugLog(
        '[SD] WebSocket handshake failed (${e.runtimeType}): $e',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  void send(WsInboundMessage message) {
    if (!isConnected) {
      _debugLog('[SD] send rejected: WebSocket is not open');
      if (!_eventsController.isClosed) {
        _eventsController.add(
          const WsErrorEvent(
            WsErrorPayload(
              code: 'socket_closed',
              message: 'The live game connection is unavailable.',
            ),
          ),
        );
      }
      return;
    }

    try {
      final jsonStr = jsonEncode(message.toJson());
      _socket!.add(jsonStr);
    } catch (e) {
      final socket = _socket;
      _socket = null;
      if (socket != null) unawaited(socket.close());
      _debugLog('[SD] send failed: $e', error: e);
      if (!_eventsController.isClosed) {
        _eventsController.add(
          WsErrorEvent(
            WsErrorPayload(code: 'socket_error', message: e.toString()),
          ),
        );
      }
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
