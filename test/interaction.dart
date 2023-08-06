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
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(tracing: true));
    final clientPayload = "client-payload";
    final serverPayload = "server-payload";

    final latch = Latch(1);

    void serve(dynamic payload, ReactiveProducer producer) {
      expect(payload, clientPayload);
      producer.produce(serverPayload);
    }

    void communicate(dynamic payload, ReactiveProducer producer) {
      expect(payload, serverPayload);
      latch.countDown();
    }

    reactive.serve(InternetAddress.anyIPv4, 12345, (connection) => connection.subcriber.subscribe("channel", serve));

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subcriber.subscribe("channel", communicate, onSubcribe: (producer) => producer.produce(clientPayload)),
    );

    await latch.done();
    await reactive.shutdown();
  });

  test('1 request - 2 responses', timeout: Timeout.none, () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(tracing: false));
    final clientPayload = "client-payload";
    final serverPayload = "server-payload";

    final latch = Latch(3);

    void serve(dynamic payload, ReactiveProducer producer) {
      expect(payload, clientPayload);
      producer.produce(serverPayload);
      producer.produce(serverPayload);
      latch.countDown();
    }

    void communicate(dynamic payload, ReactiveProducer producer) {
      expect(payload, serverPayload);
      latch.countDown();
    }

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (connection) => connection.subcriber.subscribe("channel", serve),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subcriber.subscribe("channel", communicate, onSubcribe: (producer) => producer.produce(clientPayload)),
    );

    await latch.done();
    await reactive.shutdown();
  });

  test('2 request - 4 responses', timeout: Timeout.none, () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(tracing: false));
    final clientPayload = "client-payload";
    final serverPayload = "server-payload";

    final latch = Latch(4);

    void serve(dynamic payload, ReactiveProducer producer) {
      expect(payload, clientPayload);
      producer.produce(serverPayload);
      producer.produce(serverPayload);
      latch.countDown();
    }

    void communicate(dynamic payload, ReactiveProducer producer) {
      expect(payload, serverPayload);
      latch.countDown();
    }

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (connection) => connection.subcriber.subscribe("channel", serve),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subcriber.subscribe("channel", communicate, onSubcribe: (producer) {
        producer.produce(clientPayload);
        producer.produce(clientPayload);
      }),
    );

    await latch.done();
    await reactive.shutdown();
  });
}
