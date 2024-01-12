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
  final void Function(ReactiveSubscriber subscriber) acceptor;
  final void Function(ReactiveException exception)? onError;
  final void Function()? onClose;
  final ReactiveBrokerConfiguration brokerConfiguration;
  final ReactiveTransportConfiguration transportConfiguration;
  final TransportTcpServerConfiguration? tcpConfiguration;
  final ReactiveLeaseConfiguration? leaseConfiguration;

  var _active = true;

  ReactiveServer({
    required this.address,
    required this.port,
    required this.acceptor,
    required this.onError,
    required this.onClose,
    required this.brokerConfiguration,
    required this.transportConfiguration,
    this.tcpConfiguration,
    this.leaseConfiguration,
  });

  void accept(TransportServerConnection connection) {
    if (!_active) return;
    final reactive = ReactiveServerConnection(
      connection,
      onError,
      (connection) {
        _connections.remove(connection);
        if (_connections.isEmpty) onClose?.call();
      },
      brokerConfiguration,
      transportConfiguration,
      leaseConfiguration: leaseConfiguration,
    );
    _connections.add(reactive);
    acceptor(reactive._subscriber);
  }

  Future<void> close() async {
    await Future.wait(_connections.toList().map((connection) => connection.close()));
    _active = false;
  }
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
      unawaited(_terminate());
    });
  }

  @override
  void writeSingle(Uint8List bytes, {void Function()? onDone}) => _connection.writeSingle(
        bytes,
        onError: (error) {
          _onError?.call(ReactiveException.fromTransport(error));
          unawaited(_terminate());
        },
        onDone: onDone,
      );

  @override
  void writeMany(List<Uint8List> bytes, bool linked, {void Function()? onDone}) => _connection.writeMany(
        bytes,
        onError: (error) {
          _onError?.call(ReactiveException.fromTransport(error));
          unawaited(_terminate());
        },
        onDone: onDone,
        linked: linked,
      );

  @override
  Future<void> close() async {
    await _broker.close(gracefulTimeout: _transportConfiguration.gracefulTimeout);
    await _connection.close(gracefulTimeout: _transportConfiguration.gracefulTimeout);
    _onClose?.call(this);
  }

  Future<void> _terminate() async {
    await _broker.close();
    await _connection.close();
    _onClose?.call(this);
  }
}
