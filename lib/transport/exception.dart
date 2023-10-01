import 'package:iouring_transport/transport/exception.dart';
import 'package:reactive_transport/transport/constants.dart';

class ReactiveException implements Exception {
  final int code;
  final String content;

  const ReactiveException(this.code, this.content);

  factory ReactiveException.fromTransport(Exception exception) {
    if (exception is TransportClosedException) return ReactiveExceptions.connectionClose;
    return ReactiveExceptions.connectionError(exception.toString());
  }

  @override
  String toString() => "code = $code, content = $content";
}

class ReactiveStateException implements Exception {
  final String message;

  const ReactiveStateException(this.message);

  @override
  String toString() => message;
}
