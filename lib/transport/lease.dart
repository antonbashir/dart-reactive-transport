import 'dart:async';
import 'dart:math';

import 'constants.dart';

class ReactiveLeaseLimiter {
  var _available = 0;
  var _timeToLive = 0;
  var _timestamp = DateTime.now().millisecondsSinceEpoch;
  var _enabled = false;

  bool get enabled => _enabled;

  @pragma(preferInlinePragma)
  bool restricted(int count) {
    if (_available < count) return true;
    if (DateTime.now().millisecondsSinceEpoch - _timestamp > _timeToLive) {
      _available = 0;
      return true;
    }
    return false;
  }

  @pragma(preferInlinePragma)
  void reconfigure(int timeToLive, int requests) {
    _enabled = true;
    _available = requests;
    _timeToLive = timeToLive;
    _timestamp = DateTime.now().millisecondsSinceEpoch;
  }

  @pragma(preferInlinePragma)
  void notify(int count) {
    _available = max(_available - count, 0);
    if (DateTime.now().millisecondsSinceEpoch - _timestamp > _timeToLive) {
      _available = 0;
    }
  }
}

class ReactiveLeaseScheduler {
  var _active = false;

  late Timer _timer;

  void start(int timeToLive, void Function() action) {
    if (_active) return;
    _active = true;
    _timer = Timer.periodic(Duration(milliseconds: timeToLive), (Timer timer) {
      if (timer.isActive == true) action();
    });
  }

  void stop() {
    if (_active) {
      _active = false;
      _timer.cancel();
    }
  }
}
