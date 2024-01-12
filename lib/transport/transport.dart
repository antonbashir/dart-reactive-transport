import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';
import 'package:meta/meta.dart';

import 'client.dart';
import 'configuration.dart';
import 'defaults.dart';
import 'exception.dart';
import 'server.dart';
import 'subscriber.dart';

class ReactiveTransport {
  final Transport _transport;
  final TransportWorker _worker;
  final ReactiveTransportConfiguration _configuration;
  final List<ReactiveServer> _servers = [];
  final List<ReactiveClient> _clients = [];

  ReactiveTransport(this._transport, this._worker, this._configuration);

  Future<void> shutdown({bool transport = false}) async {
    await Future.wait(_servers.map((server) => server.close()));
    _servers.clear();
    await Future.wait(_clients.map((client) => client.close()));
    _clients.clear();
    if (transport) await _transport.shutdown(gracefulTimeout: _configuration.gracefulTimeout);
  }

  void serve(
    InternetAddress address,
    int port,
    void Function(ReactiveSubscriber subscriber) acceptor, {
    void onError(ReactiveException exception)?,
    void onShutdown()?,
    TransportTcpServerConfiguration? tcpConfiguration,
    ReactiveBrokerConfiguration? brokerConfiguration,
    ReactiveLeaseConfiguration? leaseConfiguration,
  }) {
    final server = ReactiveServer(
      address: address,
      port: port,
      acceptor: acceptor,
      onError: onError,
      onClose: onShutdown,
      tcpConfiguration: tcpConfiguration,
      transportConfiguration: _configuration,
      brokerConfiguration: brokerConfiguration ?? ReactiveTransportDefaults.broker(),
      leaseConfiguration: leaseConfiguration,
    );
    _servers.add(server);
    _worker.servers.tcp(address, port, server.accept, configuration: tcpConfiguration);
  }

  void connect(
    InternetAddress address,
    int port,
    void Function(ReactiveSubscriber subscriber) connector, {
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
      onClose: onShutdown,
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

  @visibleForTesting
  List<ReactiveServer> get servers => _servers;

  @visibleForTesting
  List<ReactiveClient> get clients => _clients;
}
