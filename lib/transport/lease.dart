import 'dart:async';

class ReactiveLeaseLimitter {
  var _available = 0;
  var _requests = 0;
  var _enabled = false;
  Timer? _timer;

  bool get enabled => _enabled;

  bool get restricted => _enabled && _available == 0;

  void reconfigure(int timeToLive, int requests) {
    _enabled = true;
    _requests = requests;
    _available = _requests;
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: timeToLive), () {
      if (_timer?.isActive == true) _available = 0;
    });
  }

  void notify(int count) {
    _available -= count;
    _available = _available < 0 ? 0 : _available;
  }
}

class ReactiveLeaseScheduler {
  bool _active = false;

  late Timer _timer;

  void schedule(int timeToLive, void Function() action) {
    _timer = Timer.periodic(Duration(milliseconds: timeToLive), (Timer timer) {
      if (timer.isActive == true) action();
    });
    _active = true;
  }

  void stop() {
    if (_active) _timer.cancel();
  }
}
