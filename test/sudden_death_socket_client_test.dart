import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/sudden_death_socket_client.dart';
import 'package:skillverse_app/features/quiz/data/models/sudden_death_ws_dto.dart';

void main() {
  test('server close becomes a reconnectable socket_closed event', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final acceptedSocket = Completer<WebSocket>();
    final serverSubscription = server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      acceptedSocket.complete(socket);
    });
    final client = IoSuddenDeathSocketClient();
    final socketClosed = client.events
        .where((event) => event is WsErrorEvent)
        .cast<WsErrorEvent>()
        .firstWhere((event) => event.payload.code == 'socket_closed');

    try {
      await client.connect(
        Uri.parse('ws://127.0.0.1:${server.port}/ws/game?session_id=test'),
      );
      expect(client.isConnected, isTrue);

      final socket = await acceptedSocket.future;
      await socket.close(WebSocketStatus.goingAway, 'network switch');

      final event = await socketClosed.timeout(const Duration(seconds: 2));
      expect(event.payload.message, contains('network switch'));
      expect(client.isConnected, isFalse);
    } finally {
      await client.dispose();
      await serverSubscription.cancel();
      await server.close(force: true);
    }
  });
}
