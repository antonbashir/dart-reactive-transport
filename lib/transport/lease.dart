import 'dart:async';
import 'dart:math';

class ReactiveLeaseLimiter {
  var _available = 0;
  var _enabled = false;
  Timer? _timer;

  bool get enabled => _enabled;
  bool get restricted => _enabled && _available == 0;

  void reconfigure(int timeToLive, int requests) {
    _enabled = true;
    _available = requests;
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: timeToLive), () {
      if (_timer?.isActive == true) _available = 0;
    });
  }

  void notify(int count) {
    _available = max(_available - count, 0);
  }
}

class ReactiveLeaseScheduler {
  var _active = false;

  late Timer _timer;

  void schedule(int timeToLive, void Function() action) {
    if (_active) return;
    _active = true;
    _timer = Timer.periodic(Duration(milliseconds: timeToLive), (Timer timer) {
      if (timer.isActive == true) action();
    });
  }

  void stop() {
    if (_active) {
      _timer.cancel();
      _active = false;
    }
  }
}
