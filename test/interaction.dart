import 'dart:async';
import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';
import 'package:reactive_transport/transport/constants.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/producer.dart';
import 'package:reactive_transport/transport/transport.dart';
import 'package:test/test.dart';

import 'latch.dart';

void interaction() {
  test('1 request -> 1 cancel', timeout: Timeout(Duration(seconds: 60)), () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final clientPayload = "client-payload";

    final latch = Latch(2);

    void serve(dynamic payload, ReactiveProducer producer) {
      expect(payload, clientPayload);
      producer.cancel();
      latch.notify();
    }

    reactive.serve(InternetAddress.anyIPv4, 12345, (subscriber) => subscriber.subscribe("channel", onPayload: serve));

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onCancel: (producer) => latch.notify(),
        onSubscribe: (producer) {
          producer.payload(clientPayload);
          producer.request(1);
        },
      ),
    );

    await latch.done();
    await reactive.shutdown(transport: true);
  });

  test('1 request -> 1 response', timeout: Timeout(Duration(seconds: 60)), () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final clientPayload = "client-payload";
    final serverPayload = "server-payload";

    final latch = Latch(2);

    void serve(dynamic payload, ReactiveProducer producer) {
      expect(payload, clientPayload);
      producer.payload(serverPayload, complete: true);
      latch.notify();
    }

    void communicate(dynamic payload, ReactiveProducer producer) {
      expect(payload, serverPayload);
      latch.notify();
    }

    reactive.serve(InternetAddress.anyIPv4, 12345, (subscriber) => subscriber.subscribe("channel", onPayload: serve));

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onPayload: communicate,
        onSubscribe: (producer) {
          producer.payload(clientPayload);
          producer.request(1);
        },
      ),
    );

    await latch.done();
    await reactive.shutdown(transport: true);
  });

  test('1 request -> 2 responses', timeout: Timeout(Duration(seconds: 60)), () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final clientPayload = "client-payload";
    final serverPayload = "server-payload";

    final latch = Latch(3);

    void serve(dynamic payload, ReactiveProducer producer) {
      expect(payload, clientPayload);
      producer.payload(serverPayload);
      producer.payload(serverPayload, complete: true);
      latch.notify();
    }

    void communicate(dynamic payload, ReactiveProducer producer) {
      expect(payload, serverPayload);
      latch.notify();
    }

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (subscriber) => subscriber.subscribe("channel", onPayload: serve),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onPayload: communicate,
        onSubscribe: (producer) {
          producer.payload(clientPayload);
          producer.request(2);
        },
      ),
    );

    await latch.done();
    await reactive.shutdown(transport: true);
  });

  test('2 request -> 4 responses', timeout: Timeout(Duration(seconds: 60)), () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final clientPayload = "client-payload";
    final serverPayload = "server-payload";

    final latch = Latch(6);

    void serve(dynamic payload, ReactiveProducer producer) {
      expect(payload, clientPayload);
      producer.request(1);
      producer.payload(serverPayload);
      producer.payload(serverPayload);
      latch.notify();
    }

    void communicate(dynamic payload, ReactiveProducer producer) {
      expect(payload, serverPayload);
      latch.notify();
    }

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (subscriber) => subscriber.subscribe("channel", onPayload: serve),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onPayload: communicate,
        onSubscribe: (producer) {
          producer.payload(clientPayload);
          producer.payload(clientPayload);
          producer.request(4);
        },
      ),
    );

    await latch.done();
    await reactive.shutdown(transport: true);
  });

  test('infinity requests -> infinity responses', timeout: Timeout(Duration(seconds: 60)), () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final clientPayload = "client-payload";
    final serverPayload = "server-payload";

    final clientLatch = Latch(100);
    final serverLatch = Latch(100);

    void serve(dynamic payload, ReactiveProducer producer) {
      expect(payload, clientPayload);
      serverLatch.notify();
    }

    void communicate(dynamic payload, ReactiveProducer producer) {
      expect(payload, serverPayload);
      clientLatch.notify();
    }

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onPayload: serve,
        onSubscribe: (producer) {
          Stream.periodic(Duration.zero).take(500).listen((event) => producer.payload(serverPayload));
        },
      ),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        configuration: ReactiveTransportDefaults.channel().copyWith(initialRequestCount: reactiveInfinityRequestsCount),
        onPayload: communicate,
        onSubscribe: (producer) {
          producer.request(reactiveInfinityRequestsCount);
          Stream.periodic(Duration.zero).take(500).listen((event) => producer.payload(clientPayload));
        },
      ),
    );

    await serverLatch.done();
    await clientLatch.done();
    await reactive.shutdown(transport: true);
  });
}
