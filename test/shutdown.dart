import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:iouring_transport/iouring_transport.dart';
import 'package:reactive_transport/transport/constants.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/producer.dart';
import 'package:reactive_transport/transport/transport.dart';
import 'package:test/test.dart';

import 'latch.dart';

void shutdown() {
  test("shutdown (before initialization)", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final serverReactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final clientReactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());

    serverReactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onSubscribe: (producer) {},
      ),
    );

    clientReactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onSubscribe: (producer) {},
      ),
    );

    await serverReactive.shutdown();
    await clientReactive.shutdown();
    expect(true, serverReactive.servers.isEmpty);
    expect(true, clientReactive.clients.isEmpty);
    await transport.shutdown();
  });

  test("shutdown (after initialization)", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final serverReactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final clientReactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());

    final latch = Latch(2);

    serverReactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onSubscribe: (producer) {
          latch.notify();
        },
      ),
    );

    clientReactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onSubscribe: (producer) {
          latch.notify();
        },
      ),
    );

    await latch.done();

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
      (subscriber) => subscriber.subscribe(
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
      (subscriber) => subscriber.subscribe(
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

  test("graceful shutdown (fragmentation)", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final serverReactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(gracefulTimeout: Duration(seconds: 1)));
    final clientReactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(gracefulTimeout: Duration(seconds: 1)));
    final fullPayload = Uint8List.fromList(List.generate(1 * 1024 * 1024, (index) => 31));

    final latch = Latch(1);

    serverReactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onPayload: (payload, producer) {
          expect(ListEquality().equals(payload, fullPayload), true);
          latch.notify();
        },
      ),
    );

    clientReactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      setupConfiguration: ReactiveTransportDefaults.setup().copyWith(dataMimeType: octetStreamMimeType),
      (subscriber) => subscriber.subscribe(
        "channel",
        configuration: ReactiveTransportDefaults.channel().copyWith(frameMaxSize: 1024, fragmentSize: 256, chunksLimit: 2),
        onPayload: (payload, producer) {},
        onRequest: (count, producer) {
          producer.payload(fullPayload);
          clientReactive.shutdown();
        },
      ),
    );

    await latch.done();

    await serverReactive.shutdown();
    await transport.shutdown();
  });
}
