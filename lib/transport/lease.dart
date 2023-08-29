class ReactiveLease {
  var _available = 0;
  var _timeToLive = 0;
  var _requests = 0;
  var _enabled = false;

  bool get enabled => _enabled;

  bool get restricted => _enabled && _available == 0;

  void reconfigure(int timeToLive, int requests) {
    _enabled = true;
    _timeToLive = timeToLive;
    _requests = requests;
    _available = _requests;
  }

  void notify(int count) {
    _available -= count;
    _available = _available < 0 ? 0 : _available;
  }
}
