import 'package:iouring_transport/transport/exception.dart';
import 'constants.dart';

class ReactiveException implements Exception {
  final int code;
  final String content;

  const ReactiveException(this.code, this.content);

  factory ReactiveException.fromTransport(Exception exception) {
    if (exception is TransportClosedException) return ReactiveExceptions.connectionClose;
    return ReactiveExceptions.connectionError(exception.toString());
  }

  @override
  String toString() => "$code: $content";
}
