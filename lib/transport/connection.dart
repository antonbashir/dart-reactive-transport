import 'dart:async';
import 'dart:typed_data';

abstract interface class ReactiveConnection {
  void writeSingle(Uint8List bytes, {void Function()? onDone});

  void writeMany(List<Uint8List> bytes, bool linked, {void Function()? onDone});

  Future<void> close();
}
