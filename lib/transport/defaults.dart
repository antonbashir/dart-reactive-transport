import 'dart:typed_data';

import 'package:reactive_transport/transport/codec.dart';
import 'package:reactive_transport/transport/constants.dart';

import 'configuration.dart';

class ReactiveTransportDefaults {
  ReactiveTransportDefaults._();

  static ReactiveTransportConfiguration transport() => ReactiveTransportConfiguration(
        tracing: false,
      );

  static ReactiveChannelConfiguration channel() => ReactiveChannelConfiguration(
        requestCount: 1,
        codecs: {
          messagePackMimeType: MessagePackReactiveCodec(),
          octetStreamMimeType: RawReactiveCodec(),
          textMimeType: Utf8ReactiveCodec(),
        },
      );

  static ReactiveSetupConfiguration setup() => ReactiveSetupConfiguration(
        metadataMimeType: 'application/message-pack',
        dataMimeType: 'application/message-pack',
        keepAliveInterval: 20 * 1000,
        keepAliveMaxLifetime: 90 * 1000,
        flags: 0,
        initialData: Uint8List.fromList([]),
        initialMetaData: Uint8List.fromList([]),
      );
}
