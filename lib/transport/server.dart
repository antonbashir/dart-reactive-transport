import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';

import 'configuration.dart';
import 'connection.dart';
import 'exception.dart';
import 'state.dart';

class ReactiveServer {
  final List<ReactiveServerConnection> _connections = [];
  final InternetAddress address;
  final int port;
  final void Function(ReactiveServerConnection connection) acceptor;
  final void Function(ReactiveException exception)? onError;
  final ReactiveBrokerConfiguration brokerConfiguration;
  final ReactiveTransportConfiguration transportConfiguration;
  final TransportTcpClientConfiguration? tcpConfiguration;
  final TransportRetryConfiguration? connectRetry;

  ReactiveServer({
    required this.address,
    required this.port,
    required this.acceptor,
    required this.onError,
    required this.brokerConfiguration,
    required this.transportConfiguration,
    this.tcpConfiguration,
    this.connectRetry,
  });

  void accept(TransportServerConnection connection) {
    final reactive = ReactiveServerConnection(
      connection,
      onError,
      brokerConfiguration,
      transportConfiguration,
      ReactiveResumeServerState(transportConfiguration.resumeStore),
    );
    _connections.add(reactive);
    acceptor(reactive);
  }

  Future<void> shutdown({Duration? gracefulDuration}) async {
    await Future.wait(_connections.map((connection) => connection.close(gracefulDuration: gracefulDuration)));
  }
}
