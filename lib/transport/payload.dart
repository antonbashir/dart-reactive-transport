import 'dart:convert';
import 'dart:typed_data';

import 'constants.dart';

class ReactivePayload {
  final Uint8List metadata;
  final Uint8List data;

  ReactivePayload(this.metadata, this.data);

  static final empty = ReactivePayload.ofData(emptyBytes);

  factory ReactivePayload.ofData(Uint8List data) => ReactivePayload(emptyBytes, data);

  factory ReactivePayload.ofMetadata(Uint8List metadata) => ReactivePayload(metadata, emptyBytes);

  @override
  String toString() => 'ReactivePayload(metadata: [${metadata.length}] ${utf8.decode(metadata, allowMalformed: true)}, data: [${data.length}] ${utf8.decode(data, allowMalformed: true)})';
}
