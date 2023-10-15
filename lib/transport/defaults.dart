import 'package:iouring_transport/iouring_transport.dart';

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
        fragmentSize: 5 * 1024 * 1024,
        frameMaxSize: 10 * 1024 * 1024,
      );

  static ReactiveBrokerConfiguration broker() => ReactiveBrokerConfiguration(
        codecs: {
          messagePackMimeType: MessagePackReactiveCodec(),
          octetStreamMimeType: RawReactiveCodec(),
          textMimeType: Utf8ReactiveCodec(),
        },
        lease: null,
      );

  static ReactiveSetupConfiguration setup() => ReactiveSetupConfiguration(
        metadataMimeType: messagePackMimeType,
        dataMimeType: messagePackMimeType,
        keepAliveInterval: Duration(seconds: 20),
        keepAliveMaxLifetime: Duration(seconds: 90),
        lease: false,
      );
}
