import 'package:iouring_transport/transport/exception.dart';
import 'package:reactive_transport/transport/constants.dart';

class ReactiveException {
  final int code;
  final dynamic content;

  const ReactiveException(this.code, this.content);

  factory ReactiveException.fromTransport(Exception exception) {
    if (exception is TransportClosedException) return ReactiveExceptions.connectionClose;
    return ReactiveExceptions.connectionError(exception.toString());
  }
}
