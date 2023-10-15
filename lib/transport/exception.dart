import 'package:iouring_transport/transport/exception.dart';

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

class ReactiveExceptions {
  ReactiveExceptions._();

  static const applicationErrorCode = 0x00000201;
  static const connectionErrorCode = 0x00000101;
  static const invalidSetupCode = 0x00000001;
  static const unsupportedSetupCode = 0x00000002;
  static const rejectedSetupCode = 0x00000003;
  static const connectionCloseCode = 0x00000102;
  static const rejectedRequestCode = 0x00000202;
  static const canceledRequestCode = 0x00000203;
  static const invalidRequestCode = 0x00000204;

  static connectionError(String message) => ReactiveException(
        connectionErrorCode,
        message,
      );

  static const invalidSetup = ReactiveException(
    invalidSetupCode,
    "The Setup frame is invalid",
  );

  static const unsupportedSetup = ReactiveException(
    unsupportedSetupCode,
    "Some (or all) of the parameters specified by the client are unsupported by the server",
  );

  static const rejectedSetup = ReactiveException(
    rejectedSetupCode,
    "The server rejected the setup, it can specify the reason in the payload",
  );

  static const connectionClose = ReactiveException(
    connectionCloseCode,
    "The connection is being closed",
  );

  static const rejected = ReactiveException(
    rejectedRequestCode,
    "Despite being a valid request, the Responder decided to reject it",
  );

  static const canceled = ReactiveException(
    canceledRequestCode,
    "The Responder canceled the request but may have started processing it",
  );

  static const invalid = ReactiveException(
    invalidRequestCode,
    "The request is invalid",
  );

  static const reservedExtension = ReactiveException(
    0xFFFFFFFF,
    "Reserved for Extension",
  );

  static bool isApplicationError(int code) => code == applicationErrorCode;
}
