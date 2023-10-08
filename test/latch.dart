import 'dart:async';

class Latch {
  var _counter = 0;
  final int _limit;
  final Completer _completer = Completer();

  Latch(this._limit);

  void notify() {
    if (++_counter == _limit) _completer.complete();
  }

  Future<void> done() => _completer.future;
}

class EventLatch {
  final Map<String, bool> _events;
  final Completer _completer = Completer();
  final bool trace;

  EventLatch(Set<String> events, this.trace) : _events = Map.fromEntries(events.map((event) => MapEntry(event, false)));

  void notify(String event) {
    _events[event] = true;
    if (trace) print(event);
    if (_events.values.every((element) => element)) _completer.complete();
  }

  Future<void> done() => _completer.future;
}
