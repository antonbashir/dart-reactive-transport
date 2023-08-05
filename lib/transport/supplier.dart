import 'constants.dart';

class ReactiveStreamIdSupplier {
  var current = 0;
  late int initial;

  static ReactiveStreamIdSupplier client() => ReactiveStreamIdSupplier._streamId(reactiveClientInitialStreamId);

  static ReactiveStreamIdSupplier server() => ReactiveStreamIdSupplier._streamId(reactiveServerInitialStreamId);

  int next(Map<int, dynamic> streamIds) {
    var next = 0;
    do {
      current += reactiveStreamIdIncrement;
      if (current > reactiveStreamIdMask) {
        current = initial + reactiveStreamIdIncrement;
      }
      next = current;
    } while (next == 0 || streamIds.containsKey(next));
    return next;
  }

  ReactiveStreamIdSupplier._streamId(int streamId) {
    this.current = streamId;
    initial = streamId;
  }
}
