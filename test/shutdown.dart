import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/producer.dart';
import 'package:reactive_transport/transport/transport.dart';
import 'package:test/test.dart';

import 'latch.dart';

void shutdown() {
  test("shutdown", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final serverReactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final clientReactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final clientPayload = "client-payload";

    void serve(dynamic payload, ReactiveProducer producer) {}

    void communicate(dynamic payload, ReactiveProducer producer) {}

    serverReactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (connection) => connection.subscriber.subscribe(
        "channel",
        onPayload: serve,
        onSubscribe: (producer) {
          producer.payload(clientPayload);
        },
      ),
    );

    clientReactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subscriber.subscribe(
        "channel",
        onPayload: communicate,
        onSubscribe: (producer) {
          producer.request(1);
        },
      ),
    );

    await serverReactive.shutdown();
    await clientReactive.shutdown();
    expect(true, serverReactive.servers.isEmpty);
    expect(true, clientReactive.clients.isEmpty);
    await transport.shutdown();
  });

  test("graceful shutdown", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final serverReactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(gracefulTimeout: Duration(seconds: 1)));
    final clientReactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(gracefulTimeout: Duration(seconds: 1)));
    final clientPayload = "client-payload";
    final serverPayload = "server-payload";

    final clientLatch = Latch(1);
    final serverLatch = Latch(2);

    void serve(dynamic payload, ReactiveProducer producer) {
      expect(payload, clientPayload);
      serverLatch.notify();
    }

    void communicate(dynamic payload, ReactiveProducer producer) {
      expect(payload, serverPayload);
      clientLatch.notify();
      producer.payload(clientPayload);
      clientReactive.shutdown();
    }

    serverReactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (connection) => connection.subscriber.subscribe(
        "channel",
        onPayload: serve,
        onSubscribe: (producer) {
          producer.request(2);
          producer.payload(serverPayload);
        },
      ),
    );

    clientReactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subscriber.subscribe(
        "channel",
        onPayload: communicate,
        onSubscribe: (producer) {
          producer.request(1);
          producer.payload(clientPayload);
        },
      ),
    );

    await serverLatch.done();
    await clientLatch.done();
    await serverReactive.shutdown();
    await transport.shutdown();
  });

  test("graceful shutdown (fragmentation)", () {});
}
