import 'dart:convert';
import 'dart:typed_data';

import 'package:iouring_transport/transport/exception.dart';
import 'package:reactive_transport/transport/constants.dart';

class ReactiveException implements Exception {
  final int code;
  final String _content;
  Uint8List get content => Uint8List.fromList(utf8.encode(_content));

  const ReactiveException(this.code, this._content);

  factory ReactiveException.fromTransport(Exception exception) {
    if (exception is TransportClosedException) return ReactiveExceptions.connectionClose;
    return ReactiveExceptions.connectionError(exception.toString());
  }

  @override
  String toString() => "code = $code, content = $_content";
}

class ReactiveStateException implements Exception {
  final String message;

  const ReactiveStateException(this.message);

  @override
  String toString() => message;
}
