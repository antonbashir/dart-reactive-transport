import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'codec.dart';
import 'configuration.dart';
import 'constants.dart';
import 'store.dart';

class ReactiveTransportDefaults {
  ReactiveTransportDefaults._();

  static ReactiveTransportConfiguration transport() => ReactiveTransportConfiguration(
        tracer: null,
      );

  static ReactiveResumeClientConfiguration resumeClient() {
    final uuid = Uuid();
    return ReactiveResumeClientConfiguration(
      frameStore: LocalReactiveFrameStore(),
      resumeStateStore: LocalReactiveResumeClientStore(),
      tokenGenerator: () => uuid.v4obj().toBytes(),
    );
  }

  static ReactiveResumeServerConfiguration resumeServer() {
    return ReactiveResumeServerConfiguration(
      resumeStateStore: LocalReactiveResumeServerStore(),
    );
  }

  static ReactiveChannelConfiguration channel() => ReactiveChannelConfiguration(
        initialRequestCount: 1,
      );

  static ReactiveBrokerConfiguration broker() => ReactiveBrokerConfiguration(
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
