import 'dart:async';

import 'connection.dart';
import 'writer.dart';

class ReactiveKeepAliveTimer {
  final ReactiveWriter _writer;
  final ReactiveConnection _connection;

  late final Timer _pingTimer;
  late final Timer _pongTimer;

  var _lastPong = DateTime.now().millisecondsSinceEpoch;

  ReactiveKeepAliveTimer(this._writer, this._connection);

  void start(int keepAliveInterval, int keepAliveMaxLifetime) {
    _pingTimer = Timer.periodic(Duration(milliseconds: keepAliveInterval), (timer) {
      if (!timer.isActive) return;
      _connection.writeSingle(_writer.writeKeepAliveFrame(true, 0));
    });
    _pongTimer = Timer.periodic(Duration(milliseconds: keepAliveMaxLifetime), (timer) {
      if (!timer.isActive) return;
      if (DateTime.now().millisecondsSinceEpoch - _lastPong >= keepAliveMaxLifetime) {
        //TODO: IMPLEMENT ME
        return;
      }
    });
  }

  void pong(bool respond) {
    _lastPong = DateTime.now().millisecondsSinceEpoch;
    if (respond) _connection.writeSingle(_writer.writeKeepAliveFrame(false, 0));
  }

  void stop() {
    _pingTimer.cancel();
    _pongTimer.cancel();
  }
}
