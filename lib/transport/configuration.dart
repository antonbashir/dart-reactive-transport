import 'dart:typed_data';

import 'codec.dart';

class ReactiveTransportConfiguration {
  final void Function(dynamic frame)? tracer;
  final Duration? gracefulDuration;

  ReactiveTransportConfiguration({required this.tracer, required this.gracefulDuration});

  ReactiveTransportConfiguration copyWith({
    void Function(dynamic frame)? tracer,
    Duration? gracefulDuration,
  }) =>
      ReactiveTransportConfiguration(
        tracer: tracer ?? this.tracer,
        gracefulDuration: gracefulDuration ?? this.gracefulDuration,
      );
}

class ReactiveChannelConfiguration {
  final int initialRequestCount;
  final int fragmentationMtu;
  final int chunksLimit;
  final int fragmentGroupLimit;
  final int fragmentSize;

  const ReactiveChannelConfiguration({
    required this.initialRequestCount,
    required this.fragmentationMtu,
    required this.chunksLimit,
    required this.fragmentGroupLimit,
    required this.fragmentSize,
  });

  ReactiveChannelConfiguration copyWith({
    int? initialRequestCount,
    int? fragmentationMtu,
    int? chunksLimit,
    int? fragmentGroupLimit,
    int? fragmentSize,
  }) =>
      ReactiveChannelConfiguration(
        initialRequestCount: initialRequestCount ?? this.initialRequestCount,
        fragmentationMtu: fragmentationMtu ?? this.fragmentationMtu,
        fragmentGroupLimit: fragmentGroupLimit ?? this.fragmentGroupLimit,
        fragmentSize: fragmentSize ?? this.fragmentSize,
        chunksLimit: chunksLimit ?? this.chunksLimit,
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
