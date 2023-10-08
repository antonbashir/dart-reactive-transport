import 'dart:typed_data';

import 'constants.dart';

class ReactivePayload {
  final Uint8List metadata;
  final Uint8List data;

  ReactivePayload(this.metadata, this.data);

  static ReactivePayload empty = ReactivePayload.ofData(emptyBytes);

  factory ReactivePayload.ofData(Uint8List data) => ReactivePayload(emptyBytes, data);

  factory ReactivePayload.ofMetadata(Uint8List metadata) => ReactivePayload(metadata, emptyBytes);

  @override
  String toString() => 'ReactivePayload(metadata: ${metadata.length}, data: ${data.length})';
}
