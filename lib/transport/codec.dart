import 'dart:convert';
import 'dart:typed_data';

import 'package:msgpack_dart/msgpack_dart.dart';

import 'constants.dart';

abstract interface class ReactiveCodec {
  String mimeType();
  Uint8List encode(dynamic input);
  dynamic decode(Uint8List input);
}

class ReactiveMessagePackCodec implements ReactiveCodec {
  @override
  dynamic decode(Uint8List input) => deserialize(input);

  @override
  Uint8List encode(dynamic input) => serialize(input);

  @override
  String mimeType() => messagePackMimeType;
}

class ReactiveUtf8Codec implements ReactiveCodec {
  @override
  dynamic decode(Uint8List input) => utf8.decode(input);

  @override
  Uint8List encode(dynamic input) => Uint8List.fromList(utf8.encode(input));

  @override
  String mimeType() => textMimeType;
}

class ReactiveRawCodec implements ReactiveCodec {
  @override
  dynamic decode(Uint8List input) => input;

  @override
  Uint8List encode(dynamic input) => input;

  @override
  String mimeType() => octetStreamMimeType;
}
