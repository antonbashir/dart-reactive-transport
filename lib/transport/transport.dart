import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';
import 'client.dart';
import 'defaults.dart';
import 'exception.dart';

import 'configuration.dart';
import 'connection.dart';
import 'server.dart';

class ReactiveTransport {
  final Transport _transport;
  final TransportWorker _worker;
  final ReactiveTransportConfiguration _configuration;
  final List<ReactiveServer> _servers = [];
  final List<ReactiveClient> _clients = [];

  ReactiveTransport(this._transport, this._worker, this._configuration);

  Future<void> shutdown({Duration? gracefulDuration, bool worker = true}) async {
    await Future.wait(_servers.map((server) => server.shutdown(gracefulDuration: gracefulDuration)));
    await Future.wait(_clients.map((client) => client.shutdown(gracefulDuration: gracefulDuration)));
    if (worker) await _transport.shutdown(gracefulDuration: gracefulDuration);
  }

  void serve(
    InternetAddress address,
    int port,
    void Function(ReactiveServerConnection connection) acceptor, {
    void onError(ReactiveException exception)?,
    TransportTcpClientConfiguration? tcpConfiguration,
    TransportRetryConfiguration? connectRetry,
    ReactiveBrokerConfiguration? brokerConfiguration,
    ReactiveResumeServerConfiguration? resumeConfiguration,
  }) {
    final server = ReactiveServer(
      address: address,
      port: port,
      acceptor: acceptor,
      onError: onError,
      tcpConfiguration: tcpConfiguration,
      connectRetry: connectRetry,
      transportConfiguration: _configuration,
      brokerConfiguration: brokerConfiguration ?? ReactiveTransportDefaults.broker(),
      resumeConfiguration: resumeConfiguration ?? ReactiveTransportDefaults.resumeServer(),
    );
    _servers.add(server);
    _worker.servers.tcp(address, port, server.accept);
  }

  void connect(
    InternetAddress address,
    int port,
    void Function(ReactiveClientConnection connection) connector, {
    void onError(ReactiveException exception)?,
    TransportTcpClientConfiguration? tcpConfiguration,
    TransportRetryConfiguration? connectRetry,
    ReactiveSetupConfiguration? setupConfiguration,
    ReactiveBrokerConfiguration? brokerConfiguration,
    ReactiveResumeClientConfiguration? resumeConfiguration,
  }) {
    final client = ReactiveClient(
      address: address,
      port: port,
      connector: connector,
      onError: onError,
      transportConfiguration: _configuration,
      brokerConfiguration: brokerConfiguration ?? ReactiveTransportDefaults.broker(),
      setupConfiguration: setupConfiguration ?? ReactiveTransportDefaults.setup(),
      resumeConfiguration: resumeConfiguration ?? ReactiveTransportDefaults.resumeClient(),
    );
    _clients.add(client);
    _worker.clients
        .tcp(
          address,
          port,
          configuration: tcpConfiguration,
          connectRetry: connectRetry,
        )
        .then(client.connect, onError: (error) => onError?.call(ReactiveException.fromTransport(error)));
  }
}
