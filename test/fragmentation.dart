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
  test('1 fragmented request', timeout: Timeout.none, () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final fullPayload = Uint8List.fromList(List.generate(1 * 1024 * 1024, (index) => 31));

    final latch = Latch(1);

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (connection) => connection.subscriber.subscribe(
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
      (connection) => connection.subscriber.subscribe(
        "channel",
        configuration: ReactiveTransportDefaults.channel().copyWith(frameMaxSize: 1024, fragmentSize: 256, chunksLimit: 2),
        onPayload: (payload, producer) {},
        onRequest: (count, producer) => producer.payload(fullPayload),
      ),
    );

    await latch.done();

    await reactive.shutdown();
  });
}
