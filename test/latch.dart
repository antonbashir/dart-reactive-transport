import 'dart:async';

class Latch {
  var _counter = 0;
  final int _limit;
  final Completer _completer = Completer();

  int get count => _counter;

  Latch(this._limit);

  void notify() {
    if (++_counter == _limit) _completer.complete();
  }

  Future<void> done() => _completer.future;
}

class EventLatch {
  final String name;
  final Map<String, bool> _events;
  final Completer _completer = Completer();
  final bool trace;

  EventLatch(this.name, Set<String> events, {this.trace = false}) : _events = Map.fromEntries(events.map((event) => MapEntry(event, false)));

  void notify(String event) {
    if (_events[event] == true) throw Exception("$event already notified");
    _events[event] = true;
    if (trace) print("$name: $event");
    if (_events.values.every((element) => element)) _completer.complete();
  }

  Future<void> done() => _completer.future;
}
