import 'dart:collection';
import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';

import 'configuration.dart';
import 'connection.dart';
import 'exception.dart';

class ReactiveClient {
  final List<ReactiveClientConnection> _connections = [];
  final InternetAddress address;
  final int port;
  final void Function(ReactiveClientConnection connection) connector;
  final void Function(ReactiveException exception)? onError;
  final ReactiveBrokerConfiguration brokerConfiguration;
  final ReactiveTransportConfiguration transportConfiguration;
  final ReactiveResumeClientConfiguration resumeConfiguration;
  final ReactiveSetupConfiguration setupConfiguration;
  final TransportTcpClientConfiguration? tcpConfiguration;
  final TransportRetryConfiguration? connectRetry;

  ReactiveClient({
    required this.address,
    required this.port,
    required this.connector,
    required this.onError,
    required this.brokerConfiguration,
    required this.transportConfiguration,
    required this.setupConfiguration,
    required this.resumeConfiguration,
    this.tcpConfiguration,
    this.connectRetry,
  });

  void connect(TransportClientConnectionPool pool) {
    final resumeStates = Queue.from(resumeConfiguration.resumeStateStore.list("$address:$port"));
    pool.forEach((connection) {
      final state = resumeStates.removeFirst();
      final reactive = ReactiveClientConnection(
        connection,
        onError,
        brokerConfiguration,
        setupConfiguration,
        transportConfiguration,
        resumeConfiguration.frameStore,
      );
      _connections.add(reactive);
      connector(reactive);
      if (state == null) {
        reactive.connect();
        return;
      }
      reactive.resume(state);
    });
  }

  Future<void> shutdown({Duration? gracefulDuration}) async {
    await Future.wait(_connections.map((connection) => connection.close(gracefulDuration: gracefulDuration)));
  }
}
