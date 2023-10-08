import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:iouring_transport/iouring_transport.dart';
import 'broker.dart';
import 'reader.dart';
import 'responder.dart';
import 'subscriber.dart';
import 'supplier.dart';
import 'writer.dart';
import 'configuration.dart';
import 'connection.dart';
import 'exception.dart';
import 'keepalive.dart';

class ReactiveServer {
  final List<ReactiveServerConnection> _connections = [];
  final InternetAddress address;
  final int port;
  final void Function(ReactiveServerConnection connection) acceptor;
  final void Function(ReactiveException exception)? onError;
  final ReactiveBrokerConfiguration brokerConfiguration;
  final ReactiveTransportConfiguration transportConfiguration;
  final TransportTcpServerConfiguration? tcpConfiguration;

  ReactiveServer({
    required this.address,
    required this.port,
    required this.acceptor,
    required this.onError,
    required this.brokerConfiguration,
    required this.transportConfiguration,
    this.tcpConfiguration,
  });

  void accept(TransportServerConnection connection) {
    final reactive = ReactiveServerConnection(
      connection,
      onError,
      brokerConfiguration,
      transportConfiguration,
    );
    _connections.add(reactive);
    acceptor(reactive);
  }

  Future<void> shutdown() => Future.wait(_connections.map((connection) => connection.close()));
}

class ReactiveServerConnection implements ReactiveConnection {
  final _writer = ReactiveWriter();
  final _reader = ReactiveReader();
  final TransportServerConnection _connection;
  final void Function(ReactiveException exception)? _onError;
  final ReactiveBrokerConfiguration _brokerConfiguration;
  final ReactiveTransportConfiguration _transportConfiguration;

  late final ReactiveBroker _broker;
  late final ReactiveResponder _responder;
  late final ReactiveSubscriber _subscriber;
  late final ReactiveKeepAliveTimer _keepAliveTimer;

  ReactiveSubscriber get subscriber => _subscriber;

  ReactiveServerConnection(
    this._connection,
    this._onError,
    this._brokerConfiguration,
    this._transportConfiguration,
  ) {
    _keepAliveTimer = ReactiveKeepAliveTimer(_writer, this);
    final supplier = ReactiveStreamIdSupplier.server();
    final streamId = supplier.next({});
    _broker = ReactiveBroker(
      _transportConfiguration,
      _brokerConfiguration,
      this,
      _writer,
      streamId,
      _keepAliveTimer,
      _onError,
      supplier,
    );
    _responder = ReactiveResponder(_broker, _transportConfiguration.tracer, _reader, _keepAliveTimer);
    _subscriber = ReactiveSubscriber(_broker);
    _connection.stream().listen(_responder.handle, onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));
  }

  @override
  void writeSingle(Uint8List bytes, {void Function()? onDone}) => _connection.writeSingle(
        bytes,
        onError: (error) {
          _onError?.call(ReactiveException.fromTransport(error));
          unawaited(close());
        },
        onDone: onDone,
      );

  @override
  void writeMany(List<Uint8List> bytes, bool linked, {void Function()? onDone}) => _connection.writeMany(
        bytes,
        onError: (error) {
          _onError?.call(ReactiveException.fromTransport(error));
          unawaited(close());
        },
        onDone: onDone,
        linked: linked,
      );

  @override
  Future<void> close() async {
    await _connection.close(gracefulDuration: _transportConfiguration.gracefulDuration);
    _broker.close();
  }
}
