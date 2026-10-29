import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_endpoints.dart';

import '../../models/sudden_death_ws_dto.dart';
import 'sudden_death_socket_client.dart';

/// Sudden Death over HTTP (`/quiz/sudden-death/*`), exposed through the same
/// [SuddenDeathSocketClient] contract the game controller already uses.
///
/// Zoho Catalyst AppSail answers WebSocket upgrades without forwarding frames,
/// so the game runs as request/response turns. Each response carries the ordered
/// server events (`question`, `answer_result`, `power_up_result`, `game_over`,
/// `error`) that the socket used to push. This client:
/// - fetches the current question on `join_game` (also the resync path);
/// - reports `timeout` when the server-provided remaining time runs out;
/// - surfaces transport failures as `socket_error` so the controller's existing
///   reconnect + resync logic applies.
class RestSuddenDeathClient implements SuddenDeathSocketClient {
  /// Matches the backend's transition delay between `answer_result` and the next question.
  static const transitionDelay = Duration(milliseconds: 400);

  final ApiClient _apiClient;
  final StreamController<WsServerEvent> _events =
      StreamController<WsServerEvent>.broadcast();

  String? _sessionId;
  bool _open = false;
  Timer? _deadlineTimer;
  Future<void> _queue = Future.value();

  RestSuddenDeathClient(this._apiClient);

  @override
  Stream<WsServerEvent> get events => _events.stream;

  @override
  bool get isConnected => _open;

  /// [uri] only needs a `session_id` query parameter; no request is made until `join_game`.
  @override
  Future<void> connect(Uri uri) async {
    final session = uri.queryParameters['session_id'];
    if (session == null || session.isEmpty) {
      throw const ValidationException(
        'A Sudden Death session id is required.',
        'session_required',
      );
    }
    _cancelDeadline();
    _sessionId = session;
    _open = true;
  }

  @override
  void send(WsInboundMessage message) {
    if (!_open || _sessionId == null) {
      _emit(
        const WsErrorEvent(
          WsErrorPayload(
            code: 'socket_closed',
            message: 'The live game connection is unavailable.',
          ),
        ),
      );
      return;
    }
    final endpoint = switch (message.type) {
      'join_game' => ApiEndpoints.suddenDeathQuestion,
      'submit_answer' => ApiEndpoints.suddenDeathAnswer,
      'use_power_up' => ApiEndpoints.suddenDeathPowerUp,
      _ => null,
    };
    if (endpoint == null) {
      _emit(
        WsErrorEvent(
          WsErrorPayload(
            code: 'unsupported_type',
            message: 'Unsupported message type ${message.type}.',
          ),
        ),
      );
      return;
    }
    final body = {...message.data, 'session': _sessionId};
    // Requests run one at a time so results arrive in the order they were sent.
    _queue = _queue.then((_) => _post(endpoint, body));
  }

  Future<void> _post(String endpoint, Map<String, dynamic> body) async {
    final session = _sessionId;
    try {
      final data = await _apiClient.post(endpoint, body: body);
      if (session != _sessionId || !_open) return;
      final raw = data is Map<String, dynamic> ? data['events'] : null;
      if (raw is! List) return;
      await _dispatch(
        raw.whereType<Map<String, dynamic>>().map(WsServerEvent.fromJson),
      );
    } on AppException catch (e) {
      _log('request $endpoint failed: $e');
      if (session != _sessionId) return;
      if (e.code == 'not-found' || e.code == 'forbidden') {
        _emit(
          WsErrorEvent(
            WsErrorPayload(code: 'session_not_active', message: e.message),
          ),
        );
        return;
      }
      _emit(
        WsErrorEvent(WsErrorPayload(code: 'socket_error', message: e.message)),
      );
    } catch (e) {
      _log('request $endpoint failed: $e');
      if (session != _sessionId) return;
      _emit(WsErrorEvent(WsErrorPayload(code: 'socket_error', message: '$e')));
    }
  }

  Future<void> _dispatch(Iterable<WsServerEvent> events) async {
    var afterResult = false;
    for (final event in events) {
      switch (event) {
        case WsQuestionEvent(:final payload):
          if (afterResult) {
            await Future<void>.delayed(transitionDelay);
            if (!_open) return;
          }
          _armDeadline(payload.question, payload.remainingTimeMs);
        case WsPowerUpResultEvent(:final payload):
          if (payload.remainingTimeMs > 0) {
            _armDeadline(payload.question, payload.remainingTimeMs);
          }
        case WsAnswerResultEvent():
          _cancelDeadline();
          afterResult = true;
        case WsGameOverEvent():
          _cancelDeadline();
        default:
          break;
      }
      _emit(event);
      if (event is WsGameOverEvent) {
        _open = false;
        _emit(
          const WsErrorEvent(
            WsErrorPayload(
              code: 'socket_closed_normal',
              message: 'The game has finished.',
            ),
          ),
        );
      }
    }
  }

  /// When the server deadline passes without an answer, report the timeout so the
  /// backend resolves the question and returns `answer_result` + `game_over`.
  void _armDeadline(String question, int remainingMs) {
    _cancelDeadline();
    _deadlineTimer = Timer(Duration(milliseconds: remainingMs), () {
      send(
        WsInboundMessage.submitAnswer(
          question: question,
          option: 'timeout',
          session: _sessionId,
        ),
      );
    });
  }

  void _cancelDeadline() {
    _deadlineTimer?.cancel();
    _deadlineTimer = null;
  }

  void _emit(WsServerEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void dispose() {
    _cancelDeadline();
    _events.close();
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    _cancelDeadline();
    _open = false;
    _sessionId = null;
  }

  void _log(String message) {
    if (kDebugMode) developer.log('[SD] $message', name: 'SuddenDeathRest');
  }
}
