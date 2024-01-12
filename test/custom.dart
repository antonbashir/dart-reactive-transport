import 'dart:async';
import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';
import 'package:reactive_transport/transport/channel.dart';
import 'package:reactive_transport/transport/configuration.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/producer.dart';
import 'package:reactive_transport/transport/transport.dart';
import 'package:test/test.dart';

import 'latch.dart';

class _ClientChannel with ReactiveChannel {
  final String key;
  final ReactiveChannelConfiguration configuration;
  final EventLatch latch;
  final int clientRequests;
  final int serverRequests;
  final dynamic clientPayload;
  final dynamic serverPayload;
  final String? clientError;
  final String? serverError;

  _ClientChannel({
    required this.key,
    required this.configuration,
    required this.latch,
    required this.serverPayload,
    required this.clientPayload,
    required this.clientRequests,
    required this.serverRequests,
    this.clientError,
    this.serverError,
  });

  @override
  FutureOr<void> onComplete(ReactiveProducer producer) {
    latch.notify("complete");
  }

  @override
  FutureOr<void> onPayload(payload, ReactiveProducer producer) async {
    expect(payload, this.serverPayload);
    latch.notify("payload");
    if (clientError != null) {
      producer.error(clientError!);
      return;
    }
    if (serverError == null) producer.complete();
  }

  @override
  FutureOr<void> onRequest(int count, ReactiveProducer producer) {
    expect(count, this.serverRequests);
    latch.notify("request");
    producer.payload(clientPayload);
  }

  @override
  FutureOr<void> onSubscribe(ReactiveProducer producer) {
    latch.notify("subscribe");
    producer.request(clientRequests);
  }

  @override
  FutureOr<void> onError(int code, String error, ReactiveProducer producer) {
    if (serverError != null) {
      expect(error, serverError);
      latch.notify("error");
    }
  }
}

class _ServerChannel with ReactiveChannel {
  final String key;
  final ReactiveChannelConfiguration configuration;
  final EventLatch latch;
  final int clientRequests;
  final dynamic clientPayload;
  final dynamic serverPayload;
  final String? clientError;
  final String? serverError;

  _ServerChannel({
    required this.key,
    required this.configuration,
    required this.latch,
    required this.clientPayload,
    required this.serverPayload,
    required this.clientRequests,
    this.clientError,
    this.serverError,
  });

  @override
  FutureOr<void> onComplete(ReactiveProducer producer) {
    latch.notify("complete");
  }

  @override
  FutureOr<void> onPayload(payload, ReactiveProducer producer) async {
    expect(payload, this.clientPayload);
    latch.notify("payload");
    if (serverError != null) {
      producer.error(serverError!);
      return;
    }
    if (clientError == null) producer.complete();
  }

  @override
  FutureOr<void> onRequest(int count, ReactiveProducer producer) {
    expect(count, this.clientRequests);
    latch.notify("request");
    producer.payload(serverPayload);
  }

  @override
  FutureOr<void> onSubscribe(ReactiveProducer producer) {
    latch.notify("subscribe");
  }

  @override
  FutureOr<void> onError(int code, String error, ReactiveProducer producer) {
    if (clientError != null) {
      expect(error, clientError);
      latch.notify("error");
    }
  }
}

void custom() {
  test('channel', timeout: Timeout(Duration(seconds: 60)), () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());

    final clientLatch = EventLatch("client", {"complete", "payload", "request", "subscribe"});
    final clientPayload = "client-payload";

    final serverPayload = "server-payload";
    final serverLatch = EventLatch("server", {"complete", "payload", "request", "subscribe"});

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (subscriber) => subscriber.subscribeCustom(
        _ServerChannel(
          key: "channel",
          configuration: ReactiveTransportDefaults.channel(),
          latch: serverLatch,
          clientPayload: clientPayload,
          serverPayload: serverPayload,
          clientRequests: 1,
        ),
      ),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (subscriber) => subscriber.subscribeCustom(
        _ClientChannel(
          key: "channel",
          configuration: ReactiveTransportDefaults.channel(),
          latch: clientLatch,
          clientPayload: clientPayload,
          serverPayload: serverPayload,
          clientRequests: 1,
          serverRequests: 1,
        ),
      ),
    );

    await clientLatch.done();
    await serverLatch.done();

    await reactive.shutdown(transport: true);
  });

  test('channel (server error)', timeout: Timeout(Duration(seconds: 60)), () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());

    final clientLatch = EventLatch("client", {"complete", "error", "request", "subscribe"});
    final clientPayload = "client-payload";

    final serverError = "server-error";
    final serverPayload = "server-payload";
    final serverLatch = EventLatch("server", {"payload", "request", "subscribe"});

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (subscriber) => subscriber.subscribeCustom(
        _ServerChannel(
          key: "channel",
          configuration: ReactiveTransportDefaults.channel(),
          latch: serverLatch,
          clientPayload: clientPayload,
          serverPayload: serverPayload,
          clientRequests: 1,
          serverError: serverError,
        ),
      ),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (subscriber) => subscriber.subscribeCustom(
        _ClientChannel(
          key: "channel",
          configuration: ReactiveTransportDefaults.channel(),
          latch: clientLatch,
          clientPayload: clientPayload,
          serverPayload: serverPayload,
          serverError: serverError,
          clientRequests: 1,
          serverRequests: 1,
        ),
      ),
    );

    await clientLatch.done();
    await serverLatch.done();

    await reactive.shutdown(transport: true);
  });

  test('channel (client error)', timeout: Timeout(Duration(seconds: 60)), () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());

    final clientLatch = EventLatch("client", {"payload", "request", "subscribe"});
    final clientError = "client-error";
    final clientPayload = "client-payload";

    final serverPayload = "server-payload";
    final serverLatch = EventLatch("server", {"complete", "error", "request", "subscribe"});

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (subscriber) => subscriber.subscribeCustom(
        _ServerChannel(
          key: "channel",
          configuration: ReactiveTransportDefaults.channel(),
          latch: serverLatch,
          clientPayload: clientPayload,
          serverPayload: serverPayload,
          clientRequests: 1,
          clientError: clientError,
        ),
      ),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (subscriber) => subscriber.subscribeCustom(
        _ClientChannel(
          key: "channel",
          configuration: ReactiveTransportDefaults.channel(),
          latch: clientLatch,
          clientPayload: clientPayload,
          serverPayload: serverPayload,
          clientError: clientError,
          clientRequests: 1,
          serverRequests: 1,
        ),
      ),
    );

    await clientLatch.done();
    await serverLatch.done();

    await reactive.shutdown(transport: true);
  });
}
