import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';

import 'client.dart';
import 'configuration.dart';
import 'defaults.dart';
import 'exception.dart';
import 'server.dart';

class ReactiveTransport {
  final Transport _transport;
  final TransportWorker _worker;
  final ReactiveTransportConfiguration _configuration;
  final List<ReactiveServer> _servers = [];
  final List<ReactiveClient> _clients = [];

  ReactiveTransport(this._transport, this._worker, this._configuration);

  Future<void> shutdown({bool transport = true}) async {
    await Future.wait(_servers.map((server) => server.shutdown()));
    await Future.wait(_clients.map((client) => client.shutdown()));
    if (transport) await _transport.shutdown(gracefulDuration: _configuration.gracefulDuration);
  }

  void serve(
    InternetAddress address,
    int port,
    void Function(ReactiveServerConnection connection) acceptor, {
    void onError(ReactiveException exception)?,
    void onShutdown()?,
    TransportTcpServerConfiguration? tcpConfiguration,
    ReactiveBrokerConfiguration? brokerConfiguration,
  }) {
    final server = ReactiveServer(
      address: address,
      port: port,
      acceptor: acceptor,
      onError: onError,
      onShutdown: onShutdown,
      tcpConfiguration: tcpConfiguration,
      transportConfiguration: _configuration,
      brokerConfiguration: brokerConfiguration ?? ReactiveTransportDefaults.broker(),
    );
    _servers.add(server);
    _worker.servers.tcp(address, port, server.accept, configuration: tcpConfiguration);
  }

  void connect(
    InternetAddress address,
    int port,
    void Function(ReactiveClientConnection connection) connector, {
    void onError(ReactiveException exception)?,
    void onShutdown()?,
    TransportTcpClientConfiguration? tcpConfiguration,
    ReactiveSetupConfiguration? setupConfiguration,
    ReactiveBrokerConfiguration? brokerConfiguration,
  }) {
    final client = ReactiveClient(
      address: address,
      port: port,
      connector: connector,
      onError: onError,
      onShutdown: onShutdown,
      transportConfiguration: _configuration,
      tcpConfiguration: tcpConfiguration,
      brokerConfiguration: brokerConfiguration ?? ReactiveTransportDefaults.broker(),
      setupConfiguration: setupConfiguration ?? ReactiveTransportDefaults.setup(),
    );
    _clients.add(client);
    _worker.clients
        .tcp(
          address,
          port,
          configuration: tcpConfiguration,
        )
        .then(client.connect, onError: (error) => onError?.call(ReactiveException.fromTransport(error)));
  }
}
