import 'dart:typed_data';

import 'codec.dart';

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
  final ReactiveLeaseConfiguration? lease;

  const ReactiveBrokerConfiguration({
    required this.codecs,
    this.lease,
  });

  ReactiveBrokerConfiguration copyWith({
    Map<String, ReactiveCodec>? codecs,
    ReactiveLeaseConfiguration? lease,
  }) =>
      ReactiveBrokerConfiguration(
        codecs: codecs ?? this.codecs,
        lease: lease ?? this.lease,
      );
}

class ReactiveLeaseConfiguration {
  final int timeToLive;
  final int requests;

  ReactiveLeaseConfiguration({required this.timeToLive, required this.requests});

  ReactiveLeaseConfiguration copyWith({
    int? timeToLive,
    int? requests,
  }) =>
      ReactiveLeaseConfiguration(
        timeToLive: timeToLive ?? this.timeToLive,
        requests: requests ?? this.requests,
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
  final bool lease;

  ReactiveSetupConfiguration({
    required this.metadataMimeType,
    required this.dataMimeType,
    required this.keepAliveInterval,
    required this.keepAliveMaxLifetime,
    required this.flags,
    required this.initialData,
    required this.initialMetaData,
    required this.lease,
  });

  ReactiveSetupConfiguration copyWith({
    String? metadataMimeType,
    String? dataMimeType,
    int? keepAliveInterval,
    int? keepAliveMaxLifetime,
    int? flags,
    Uint8List? initialData,
    Uint8List? initialMetaData,
    bool? lease,
  }) =>
      ReactiveSetupConfiguration(
        metadataMimeType: metadataMimeType ?? this.metadataMimeType,
        dataMimeType: dataMimeType ?? this.dataMimeType,
        keepAliveInterval: keepAliveInterval ?? this.keepAliveInterval,
        keepAliveMaxLifetime: keepAliveMaxLifetime ?? this.keepAliveMaxLifetime,
        flags: flags ?? this.flags,
        initialData: initialData ?? this.initialData,
        initialMetaData: initialMetaData ?? this.initialMetaData,
        lease: lease ?? this.lease,
      );
}
