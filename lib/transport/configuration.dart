import 'package:iouring_transport/iouring_transport.dart';

import 'codec.dart';

class ReactiveTransportConfiguration {
  final void Function(dynamic frame)? tracer;
  final Duration? gracefulDuration;
  final TransportWorkerConfiguration workerConfiguration;

  ReactiveTransportConfiguration({
    required this.tracer,
    required this.gracefulDuration,
    required this.workerConfiguration,
  });

  ReactiveTransportConfiguration copyWith({
    void Function(dynamic frame)? tracer,
    Duration? gracefulDuration,
    TransportWorkerConfiguration? workerConfiguration,
  }) =>
      ReactiveTransportConfiguration(
        tracer: tracer ?? this.tracer,
        gracefulDuration: gracefulDuration ?? this.gracefulDuration,
        workerConfiguration: workerConfiguration ?? this.workerConfiguration,
      );
}

class ReactiveChannelConfiguration {
  final int initialRequestCount;
  final int frameMaxSize;
  final int chunksLimit;
  final int fragmentSize;

  const ReactiveChannelConfiguration({
    required this.initialRequestCount,
    required this.frameMaxSize,
    required this.chunksLimit,
    required this.fragmentSize,
  });

  ReactiveChannelConfiguration copyWith({
    int? initialRequestCount,
    int? frameMaxSize,
    int? chunksLimit,
    int? fragmentSize,
  }) =>
      ReactiveChannelConfiguration(
        initialRequestCount: initialRequestCount ?? this.initialRequestCount,
        frameMaxSize: frameMaxSize ?? this.frameMaxSize,
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
  final Duration timeToLiveRefresh;
  final Duration timeToLiveCheck;
  final int requests;

  ReactiveLeaseConfiguration({required this.timeToLiveCheck, required this.timeToLiveRefresh, required this.requests});

  ReactiveLeaseConfiguration copyWith({
    Duration? timeToLiveCheck,
    Duration? timeToLiveRefresh,
    int? requests,
  }) =>
      ReactiveLeaseConfiguration(
        timeToLiveCheck: timeToLiveCheck ?? this.timeToLiveCheck,
        timeToLiveRefresh: timeToLiveRefresh ?? this.timeToLiveRefresh,
        requests: requests ?? this.requests,
      );
}

class ReactiveSetupConfiguration {
  final String metadataMimeType;
  final String dataMimeType;
  final int keepAliveInterval;
  final int keepAliveMaxLifetime;
  final bool lease;

  ReactiveSetupConfiguration({
    required this.metadataMimeType,
    required this.dataMimeType,
    required this.keepAliveInterval,
    required this.keepAliveMaxLifetime,
    required this.lease,
  });

  ReactiveSetupConfiguration copyWith({
    String? metadataMimeType,
    String? dataMimeType,
    int? keepAliveInterval,
    int? keepAliveMaxLifetime,
    bool? lease,
  }) =>
      ReactiveSetupConfiguration(
        metadataMimeType: metadataMimeType ?? this.metadataMimeType,
        dataMimeType: dataMimeType ?? this.dataMimeType,
        keepAliveInterval: keepAliveInterval ?? this.keepAliveInterval,
        keepAliveMaxLifetime: keepAliveMaxLifetime ?? this.keepAliveMaxLifetime,
        lease: lease ?? this.lease,
      );
}
