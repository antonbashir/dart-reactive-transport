import 'dart:typed_data';

import 'codec.dart';
import 'store.dart';

class ReactiveTransportConfiguration {
  final void Function(dynamic frame)? tracer;

  ReactiveTransportConfiguration({required this.tracer});

  ReactiveTransportConfiguration copyWith({
    void Function(dynamic frame)? tracer,
  }) =>
      ReactiveTransportConfiguration(
        tracer: tracer ?? this.tracer,
      );
}

class ReactiveResumeClientConfiguration {
  final ReactiveFrameStore frameStore;
  final ReactiveResumeClientStore resumeStateStore;
  final Uint8List Function() tokenGenerator;

  ReactiveResumeClientConfiguration({required this.frameStore, required this.resumeStateStore, required this.tokenGenerator});

  ReactiveResumeClientConfiguration copyWith({
    ReactiveFrameStore? frameStore,
    ReactiveResumeClientStore? resumeStore,
    Uint8List Function()? tokenGenerator,
  }) =>
      ReactiveResumeClientConfiguration(
        frameStore: frameStore ?? this.frameStore,
        resumeStateStore: resumeStore ?? this.resumeStateStore,
        tokenGenerator: tokenGenerator ?? this.tokenGenerator,
      );
}

class ReactiveResumeServerConfiguration {
  final ReactiveResumeServerStore resumeStateStore;

  ReactiveResumeServerConfiguration({required this.resumeStateStore});

  ReactiveResumeServerConfiguration copyWith({
    ReactiveResumeServerStore? resumeStore,
  }) =>
      ReactiveResumeServerConfiguration(
        resumeStateStore: resumeStore ?? this.resumeStateStore,
      );
}

class ReactiveChannelConfiguration {
  final int initialRequestCount;

  const ReactiveChannelConfiguration({
    required this.initialRequestCount,
  });

  ReactiveChannelConfiguration copyWith({
    int? initialRequestCount,
  }) =>
      ReactiveChannelConfiguration(
        initialRequestCount: initialRequestCount ?? this.initialRequestCount,
      );
}

class ReactiveBrokerConfiguration {
  final Map<String, ReactiveCodec> codecs;

  const ReactiveBrokerConfiguration({
    required this.codecs,
  });

  ReactiveBrokerConfiguration copyWith({
    Map<String, ReactiveCodec>? codecs,
  }) =>
      ReactiveBrokerConfiguration(
        codecs: codecs ?? this.codecs,
      );
}

class ReactiveSetupConfiguration {
  final String metadataMimeType;
  final String dataMimeType;
  final int keepAliveInterval;
  final int keepAliveMaxLifetime;
  final int flags;
  final Uint8List initialData;
  final Uint8List initialMetaData;

  ReactiveSetupConfiguration({
    required this.metadataMimeType,
    required this.dataMimeType,
    required this.keepAliveInterval,
    required this.keepAliveMaxLifetime,
    required this.flags,
    required this.initialData,
    required this.initialMetaData,
  });

  ReactiveSetupConfiguration copyWith({
    String? metadataMimeType,
    String? dataMimeType,
    int? keepAliveInterval,
    int? keepAliveMaxLifetime,
    int? flags,
    Uint8List? initialData,
    Uint8List? initialMetaData,
  }) =>
      ReactiveSetupConfiguration(
        metadataMimeType: metadataMimeType ?? this.metadataMimeType,
        dataMimeType: dataMimeType ?? this.dataMimeType,
        keepAliveInterval: keepAliveInterval ?? this.keepAliveInterval,
        keepAliveMaxLifetime: keepAliveMaxLifetime ?? this.keepAliveMaxLifetime,
        flags: flags ?? this.flags,
        initialData: initialData ?? this.initialData,
        initialMetaData: initialMetaData ?? this.initialMetaData,
      );
}
