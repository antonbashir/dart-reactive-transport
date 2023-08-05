import 'constants.dart';

class ReactiveStreamIdSupplier {
  var current = 0;
  late int initial;

  static ReactiveStreamIdSupplier clientSupplier() {
    return ReactiveStreamIdSupplier._streamId(reactiveClientInitialStreamId);
  }

  static ReactiveStreamIdSupplier serverSupplier() {
    return ReactiveStreamIdSupplier._streamId(reactiveServerInitialStreamId);
  }

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
