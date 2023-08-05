import 'dart:convert';
import 'dart:typed_data';

import 'package:msgpack_dart/msgpack_dart.dart';

import 'constants.dart';

abstract interface class ReactiveCodec {
  String mimeType();
  Uint8List encode(dynamic input);
  dynamic decode(Uint8List input);
}

class MessagePackReactiveCodec implements ReactiveCodec {
  @override
  dynamic decode(Uint8List input) => deserialize(input);

  @override
  Uint8List encode(dynamic input) => serialize(input);

  @override
  String mimeType() => messagePackMimeType;
}

class Utf8ReactiveCodec implements ReactiveCodec {
  @override
  dynamic decode(Uint8List input) => utf8.decode(input);

  @override
  Uint8List encode(dynamic input) => Uint8List.fromList(utf8.encode(input));

  @override
  String mimeType() => textMimeType;
}

class RawReactiveCodec implements ReactiveCodec {
  @override
  dynamic decode(Uint8List input) => input;

  @override
  Uint8List encode(dynamic input) => input;

  @override
  String mimeType() => octetStreamMimeType;
}
