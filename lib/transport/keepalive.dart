import 'dart:async';

import 'package:reactive_transport/transport/writer.dart';

import 'connection.dart';

class ReactiveKeepAliveTimer {
  final ReactiveConnection _connection;

  late final Timer _pingTimer;
  late final Timer _pongTimer;

  var _lastPong = DateTime.now().millisecondsSinceEpoch;

  ReactiveKeepAliveTimer(this._connection);

  void start(int keepAliveInterval, int keepAliveMaxLifetime) {
    _pingTimer = Timer.periodic(Duration(milliseconds: keepAliveInterval), (timer) {
      if (!timer.isActive) return;
      _connection.writeSingle(ReactiveWriter.writeKeepAliveFrame(true, 0));
    });
    _pongTimer = Timer.periodic(Duration(milliseconds: keepAliveMaxLifetime), (timer) async {
      if (!timer.isActive) return;
      if (DateTime.now().millisecondsSinceEpoch - _lastPong >= keepAliveMaxLifetime) {
        await _connection.close();
        return;
      }
    });
  }

  void pong(bool respond) {
    _lastPong = DateTime.now().millisecondsSinceEpoch;
    if (respond) _connection.writeSingle(ReactiveWriter.writeKeepAliveFrame(false, 0));
  }

  void stop() {
    _pingTimer.cancel();
    _pongTimer.cancel();
  }
}
