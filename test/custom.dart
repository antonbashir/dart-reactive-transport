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

  _ClientChannel({
    required this.key,
    required this.configuration,
    required this.latch,
    required this.serverPayload,
    required this.clientPayload,
    required this.clientRequests,
    required this.serverRequests,
  });

  @override
  FutureOr<void> onComplete(ReactiveProducer producer) {
    latch.notify("complete");
  }

  @override
  FutureOr<void> onPayload(payload, ReactiveProducer producer) {
    expect(payload, this.serverPayload);
    latch.notify("payload");
    producer.complete();
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
  FutureOr<void> onError(String error, ReactiveProducer producer) => throw UnimplementedError();
}

class _ServerChannel with ReactiveChannel {
  final String key;
  final ReactiveChannelConfiguration configuration;
  final EventLatch latch;
  final int clientRequests;
  final dynamic clientPayload;
  final dynamic serverPayload;

  _ServerChannel({
    required this.key,
    required this.configuration,
    required this.latch,
    required this.clientPayload,
    required this.serverPayload,
    required this.clientRequests,
  });

  @override
  FutureOr<void> onComplete(ReactiveProducer producer) {
    latch.notify("complete");
  }

  @override
  FutureOr<void> onPayload(payload, ReactiveProducer producer) {
    expect(payload, this.clientPayload);
    latch.notify("payload");
    producer.complete();
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
  FutureOr<void> onError(String error, ReactiveProducer producer) {}
}

void custom() {
  test('custom channel', timeout: Timeout.none, () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(tracer: print));

    final clientLatch = EventLatch({"complete", "payload", "request", "subscribe"}, true);
    final clientPayload = "client-payload";

    final serverPayload = "server-payload";
    final serverLatch = EventLatch({"complete", "payload", "request", "subscribe"}, true);

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (connection) => connection.subscriber.subscribeCustom(
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
      (connection) => connection.subscriber.subscribeCustom(
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

    await reactive.shutdown();
  });
}
