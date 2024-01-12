import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:reactive_transport/transport/constants.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/transport.dart';
import 'package:test/test.dart';

import 'latch.dart';

void fragmentation() {
  test('1 fragmented request', timeout: Timeout(Duration(seconds: 60)), () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final fullPayload = Uint8List.fromList(List.generate(1 * 1024 * 1024, (index) => 31));

    final latch = Latch(1);

    reactive.serve(
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

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      setupConfiguration: ReactiveTransportDefaults.setup().copyWith(dataMimeType: octetStreamMimeType),
      (subscriber) => subscriber.subscribe(
        "channel",
        configuration: ReactiveTransportDefaults.channel().copyWith(frameMaxSize: 1024, fragmentSize: 256, chunksLimit: 2),
        onPayload: (payload, producer) {},
        onRequest: (count, producer) => producer.payload(fullPayload),
      ),
    );

    await latch.done();

    await reactive.shutdown(transport: true);
  });

  test('1 simple request -> 1 fragmented request', timeout: Timeout(Duration(seconds: 60)), () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final simplePayload = Uint8List.fromList("simple".codeUnits);
    final fullPayload = Uint8List.fromList(List.generate(1 * 1024 * 1024, (index) => 31));

    final latch = Latch(2);

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onSubscribe: (producer) => producer.request(2),
        onPayload: (payload, producer) {
          if (latch.count == 0) {
            expect(ListEquality().equals(payload, simplePayload), true);
            latch.notify();
            return;
          }
          expect(ListEquality().equals(payload, fullPayload), true);
          latch.notify();
        },
      ),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      setupConfiguration: ReactiveTransportDefaults.setup().copyWith(dataMimeType: octetStreamMimeType),
      (subscriber) => subscriber.subscribe(
        "channel",
        configuration: ReactiveTransportDefaults.channel().copyWith(frameMaxSize: 1024, fragmentSize: 256, chunksLimit: 2),
        onRequest: (count, producer) {
          producer.payload(simplePayload);
          producer.payload(fullPayload);
        },
      ),
    );

    await latch.done();

    await reactive.shutdown(transport: true);
  });

  test('1 simple request -> 1 fragmented request -> 1 simple request', timeout: Timeout(Duration(seconds: 60)), () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final simplePayload = Uint8List.fromList("simple".codeUnits);
    final fullPayload = Uint8List.fromList(List.generate(1 * 1024 * 1024, (index) => 31));

    final latch = Latch(3);

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onSubscribe: (producer) => producer.request(3),
        onPayload: (payload, producer) {
          if (latch.count == 0) {
            expect(ListEquality().equals(payload, simplePayload), true);
            latch.notify();
            return;
          }
          if (latch.count == 1) {
            expect(ListEquality().equals(payload, fullPayload), true);
            latch.notify();
            return;
          }
          expect(ListEquality().equals(payload, simplePayload), true);
          latch.notify();
        },
      ),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      setupConfiguration: ReactiveTransportDefaults.setup().copyWith(dataMimeType: octetStreamMimeType),
      (subscriber) => subscriber.subscribe(
        "channel",
        configuration: ReactiveTransportDefaults.channel().copyWith(frameMaxSize: 1024, fragmentSize: 256, chunksLimit: 2),
        onError: (code, error, producer) => print(error),
        onRequest: (count, producer) {
          producer.payload(simplePayload);
          producer.payload(fullPayload);
          producer.payload(simplePayload);
        },
      ),
    );

    await latch.done();

    await reactive.shutdown(transport: true);
  });

  test('1 simple request -> 1 fragmented request -> 1 simple request -> 1 fragmented request', timeout: Timeout(Duration(seconds: 60)), () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final simplePayload = Uint8List.fromList("simple".codeUnits);
    final fullPayload = Uint8List.fromList(List.generate(1 * 1024 * 1024, (index) => 31));

    final latch = Latch(4);

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onSubscribe: (producer) => producer.request(4),
        onPayload: (payload, producer) {
          if (latch.count == 0) {
            expect(ListEquality().equals(payload, simplePayload), true);
            latch.notify();
            return;
          }
          if (latch.count == 1) {
            expect(ListEquality().equals(payload, fullPayload), true);
            latch.notify();
            return;
          }
          if (latch.count == 2) {
            expect(ListEquality().equals(payload, simplePayload), true);
            latch.notify();
            return;
          }
          expect(ListEquality().equals(payload, fullPayload), true);
          latch.notify();
          return;
        },
      ),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      setupConfiguration: ReactiveTransportDefaults.setup().copyWith(dataMimeType: octetStreamMimeType),
      (subscriber) => subscriber.subscribe(
        "channel",
        configuration: ReactiveTransportDefaults.channel().copyWith(frameMaxSize: 1024, fragmentSize: 256, chunksLimit: 2),
        onError: (code, error, producer) => print(error),
        onRequest: (count, producer) {
          producer.payload(simplePayload);
          producer.payload(fullPayload);
          producer.payload(simplePayload);
          producer.payload(fullPayload);
        },
      ),
    );

    await latch.done();

    await reactive.shutdown(transport: true);
  });
}
