import 'package:iouring_transport/iouring_transport.dart';

import 'codec.dart';

class ReactiveTransportConfiguration {
  final void Function(dynamic frame)? tracer;
  final Duration? gracefulTimeout;
  final TransportWorkerConfiguration workerConfiguration;

  ReactiveTransportConfiguration({
    required this.tracer,
    required this.gracefulTimeout,
    required this.workerConfiguration,
  });

  ReactiveTransportConfiguration copyWith({
    void Function(dynamic frame)? tracer,
    Duration? gracefulTimeout,
    TransportWorkerConfiguration? workerConfiguration,
  }) =>
      ReactiveTransportConfiguration(
        tracer: tracer ?? this.tracer,
        gracefulTimeout: gracefulTimeout ?? this.gracefulTimeout,
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
  final Duration keepAliveInterval;
  final Duration keepAliveMaxLifetime;
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
    Duration? keepAliveInterval,
    Duration? keepAliveMaxLifetime,
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
