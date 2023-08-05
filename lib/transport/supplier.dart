import 'constants.dart';

class ReactiveStreamIdSupplier {
  var _current = 0;
  late int _initial;

  static ReactiveStreamIdSupplier client() => ReactiveStreamIdSupplier._streamId(reactiveClientInitialStreamId);

  static ReactiveStreamIdSupplier server() => ReactiveStreamIdSupplier._streamId(reactiveServerInitialStreamId);

  int next(Map<int, dynamic> streamIds) {
    var next = 0;
    do {
      _current += reactiveStreamIdIncrement;
      if (_current > reactiveStreamIdMask) {
        _current = _initial + reactiveStreamIdIncrement;
      }
      next = _current;
    } while (next == 0 || streamIds.containsKey(next));
    return next;
  }

  ReactiveStreamIdSupplier._streamId(int streamId) {
    this._current = streamId;
    _initial = streamId;
  }
}
