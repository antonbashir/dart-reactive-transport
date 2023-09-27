import 'dart:typed_data';

import 'constants.dart';

class ReactivePayload {
  final Uint8List metadata;
  final Uint8List data;

  ReactivePayload(this.metadata, this.data);

  factory ReactivePayload.ofData(Uint8List data) {
    return ReactivePayload(emptyBytes, data);
  }

  factory ReactivePayload.ofMetadata(Uint8List metadata) {
    return ReactivePayload(metadata, emptyBytes);
  }

  @override
  String toString() => 'ReactivePayload(metadata: ${metadata.length}, data: ${data.length})';
}
