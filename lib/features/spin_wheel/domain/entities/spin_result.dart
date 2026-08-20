import 'package:equatable/equatable.dart';

/// Which segment won is decided entirely by SpinWheelRepository before this
/// entity exists — the wheel widget only animates to reveal it, never
/// rolls its own outcome. Once a backend exists, that decision moves
/// server-side (Step 10) without this shape changing.
class SpinResult extends Equatable {
  final String segmentId;

  const SpinResult({required this.segmentId});

  @override
  List<Object?> get props => [segmentId];
}
