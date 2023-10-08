import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/producer.dart';
import 'package:reactive_transport/transport/transport.dart';
import 'package:test/test.dart';

import 'latch.dart';

void interaction() {
  test('1 request - 1 response', timeout: Timeout.none, () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(tracer: print));
    final clientPayload = "client-payload";
    final serverPayload = "server-payload";

    final latch = Latch(1);

    void serve(dynamic payload, ReactiveProducer producer) {
      expect(payload, clientPayload);
      producer.payload(serverPayload, complete: true);
      latch.notify();
    }

    void communicate(dynamic payload, ReactiveProducer producer) {
      expect(payload, serverPayload);
      latch.notify();
    }

    reactive.serve(InternetAddress.anyIPv4, 12345, (connection) => connection.subscriber.subscribe("channel", serve));

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subscriber.subscribe(
        "channel",
        communicate,
        onSubscribe: (producer) {
          producer.payload(clientPayload);
          producer.request(1);
        },
      ),
    );

    await latch.done();
    await reactive.shutdown();
  });

  test('1 request - 2 responses', timeout: Timeout.none, () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(tracer: print));
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
      (connection) => connection.subscriber.subscribe("channel", serve),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subscriber.subscribe(
        "channel",
        communicate,
        onSubscribe: (producer) {
          producer.payload(clientPayload);
          producer.request(2);
        },
      ),
    );

    await latch.done();
    await reactive.shutdown();
  });

  test('2 request - 4 responses', timeout: Timeout.none, () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(tracer: print));
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
      (connection) => connection.subscriber.subscribe("channel", serve),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subscriber.subscribe(
        "channel",
        communicate,
        onSubscribe: (producer) {
          producer.payload(clientPayload);
          producer.payload(clientPayload);
          producer.request(4);
        },
      ),
    );

    await latch.done();
    await reactive.shutdown();
  });
}
