import '../../models/sudden_death_ws_dto.dart';

/// Event transport for Sudden Death. Implemented over HTTP by `RestSuddenDeathClient`.
abstract class SuddenDeathSocketClient {
  /// Server events in the order the backend produced them.
  Stream<WsServerEvent> get events;

  /// Whether a live session is bound and not finished.
  bool get isConnected;

  /// Binds to the session identified by the `session_id` query parameter of [uri].
  Future<void> connect(Uri uri);

  /// Sends a `join_game`, `submit_answer` or `use_power_up` message.
  void send(WsInboundMessage message);

  /// Stops the session binding.
  Future<void> close([int? code, String? reason]);
}
