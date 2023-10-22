import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:iouring_transport/iouring_transport.dart';

import 'broker.dart';
import 'configuration.dart';
import 'connection.dart';
import 'exception.dart';
import 'keepalive.dart';
import 'responder.dart';
import 'subscriber.dart';
import 'supplier.dart';

class ReactiveServer {
  final List<ReactiveServerConnection> _connections = [];
  final InternetAddress address;
  final int port;
  final void Function(ReactiveServerConnection connection) acceptor;
  final void Function(ReactiveException exception)? onError;
  final void Function()? onShutdown;
  final ReactiveBrokerConfiguration brokerConfiguration;
  final ReactiveTransportConfiguration transportConfiguration;
  final TransportTcpServerConfiguration? tcpConfiguration;
  final ReactiveLeaseConfiguration? leaseConfiguration;

  ReactiveServer({
    required this.address,
    required this.port,
    required this.acceptor,
    required this.onError,
    required this.onShutdown,
    required this.brokerConfiguration,
    required this.transportConfiguration,
    this.tcpConfiguration,
    this.leaseConfiguration,
  });

  void accept(TransportServerConnection connection) {
    final reactive = ReactiveServerConnection(
      connection,
      onError,
      (connection) {
        _connections.remove(connection);
        if (_connections.isEmpty) onShutdown?.call();
      },
      brokerConfiguration,
      transportConfiguration,
      leaseConfiguration: leaseConfiguration,
    );
    _connections.add(reactive);
    acceptor(reactive);
  }

  Future<void> close() => Future.wait(_connections.map((connection) => connection.close())).whenComplete(() => onShutdown?.call());
}

class ReactiveServerConnection implements ReactiveConnection {
  final TransportServerConnection _connection;
  final void Function(ReactiveException exception)? _onError;
  final void Function(ReactiveServerConnection connection)? _onClose;
  final ReactiveBrokerConfiguration _brokerConfiguration;
  final ReactiveTransportConfiguration _transportConfiguration;
  final ReactiveLeaseConfiguration? leaseConfiguration;

  late final ReactiveBroker _broker;
  late final ReactiveResponder _responder;
  late final ReactiveSubscriber _subscriber;
  late final ReactiveKeepAliveTimer _keepAliveTimer;

  ReactiveSubscriber get subscriber => _subscriber;

  ReactiveServerConnection(
    this._connection,
    this._onError,
    this._onClose,
    this._brokerConfiguration,
    this._transportConfiguration, {
    this.leaseConfiguration,
  }) {
    _keepAliveTimer = ReactiveKeepAliveTimer(this);
    final supplier = ReactiveStreamIdSupplier.server();
    final streamId = supplier.next({});
    _broker = ReactiveBroker(
      _transportConfiguration,
      _brokerConfiguration,
      this,
      streamId,
      _keepAliveTimer,
      _onError,
      supplier,
      leaseConfiguration: leaseConfiguration,
    );
    _responder = ReactiveResponder(_broker, _transportConfiguration.tracer, _keepAliveTimer);
    _subscriber = ReactiveSubscriber(_broker);
    _connection.stream().listen(_responder.handle, onError: (error) {
      _onError?.call(ReactiveException.fromTransport(error));
      unawaited(close());
    });
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
    await _broker.close();
    await _connection.close(gracefulTimeout: _transportConfiguration.gracefulTimeout);
    _onClose?.call(this);
  }
}
