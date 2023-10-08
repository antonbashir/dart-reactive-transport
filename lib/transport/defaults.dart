import 'dart:typed_data';
import 'package:iouring_transport/transport/defaults.dart';

import 'codec.dart';
import 'configuration.dart';
import 'constants.dart';

class ReactiveTransportDefaults {
  ReactiveTransportDefaults._();

  static ReactiveTransportConfiguration transport() => ReactiveTransportConfiguration(
        tracer: null,
        gracefulDuration: null,
        workerConfiguration: TransportDefaults.worker(),
      );

  static ReactiveChannelConfiguration channel() => ReactiveChannelConfiguration(
        initialRequestCount: 1,
        chunksLimit: 8,
        fragmentSize: 32 * 1024 * 1024,
        fragmentationMtu: 64 * 1024 * 1024,
      );

  static ReactiveBrokerConfiguration broker() => ReactiveBrokerConfiguration(
        codecs: {
          messagePackMimeType: MessagePackReactiveCodec(),
          octetStreamMimeType: RawReactiveCodec(),
          textMimeType: Utf8ReactiveCodec(),
        },
        lease: ReactiveLeaseConfiguration(timeToLive: Duration(seconds: 1), requests: 1000),
      );

  static ReactiveSetupConfiguration setup() => ReactiveSetupConfiguration(
        metadataMimeType: messagePackMimeType,
        dataMimeType: messagePackMimeType,
        keepAliveInterval: 20 * 1000,
        keepAliveMaxLifetime: 90 * 1000,
        flags: 0,
        initialData: Uint8List.fromList([]),
        initialMetaData: Uint8List.fromList([]),
        lease: true,
      );
}
