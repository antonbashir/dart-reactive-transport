import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/producer.dart';
import 'package:reactive_transport/transport/transport.dart';
import 'package:test/test.dart';

import 'latch.dart';

void interaction() {
  test('[manual] 1 request - 1 response', timeout: Timeout.none, () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(tracing: false));
    final clientPayload = "client-payload";
    final serverPayload = "server-payload";

    final latch = Latch(2);

    void serve(dynamic payload, ReactiveProducer producer) {
      expect(payload, clientPayload);
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
      (connection) => connection.subcriber.subscribe("channel", serve, onSubcribe: (producer) => producer.request(1)),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subcriber.subscribe("channel", communicate, onSubcribe: (producer) {
        producer.produce(clientPayload);
        producer.request(1);
      }),
    );

    await latch.done();
    await reactive.shutdown();
  });

  test('[manual] 1 request - 2 responses', timeout: Timeout.none, () async {
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
      producer.request(1);
    }

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (connection) => connection.subcriber.subscribe("channel", serve, onSubcribe: (producer) => producer.request(1)),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subcriber.subscribe("channel", communicate, onSubcribe: (producer) {
        producer.produce(clientPayload);
        producer.request(1);
      }),
    );

    await latch.done();
    await reactive.shutdown();
  });

  test('[manual] 2 request - 4 responses', timeout: Timeout.none, () async {
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
      producer.request(1);
    }

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (connection) => connection.subcriber.subscribe("channel", serve, onSubcribe: (producer) => producer.request(2)),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subcriber.subscribe("channel", communicate, onSubcribe: (producer) {
        producer.produce(clientPayload);
        producer.produce(clientPayload);
        producer.request(1);
      }),
    );

    await latch.done();
    await reactive.shutdown();
  });

  test('[auto] 3 request - 2 response', timeout: Timeout.none, () async {
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
      latch.countDown();
    }

    void communicate(dynamic payload, ReactiveProducer producer) {
      expect(payload, serverPayload);
      producer.produce(clientPayload);
      latch.countDown();
    }

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      channelConfiguration: ReactiveTransportDefaults.channel().copyWith(automaticRequest: true),
      (connection) => connection.subcriber.subscribe("channel", serve, onSubcribe: (producer) => producer.request(1)),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      channelConfiguration: ReactiveTransportDefaults.channel().copyWith(automaticRequest: true),
      (connection) => connection.subcriber.subscribe("channel", communicate, onSubcribe: (producer) {
        producer.produce(clientPayload);
        producer.request(1);
      }),
    );

    await latch.done();
    await reactive.shutdown();
  });
}
