import 'dart:typed_data';

import 'payload.dart';

class FrameHeader {
  final int frameLength;
  final int streamId;
  final int type;
  final int flags;
  final bool metaPresent;

  FrameHeader(
    this.frameLength,
    this.streamId,
    this.type,
    this.flags,
    this.metaPresent,
  );

  @override
  String toString() {
    return 'FrameHeader(frameLength: $frameLength, streamId: $streamId, type: $type, flags: $flags, metaPresent: $metaPresent)';
  }
}

class SetupFrame {
  final FrameHeader header;
  final String metadataMimeType;
  final String dataMimeType;
  final int keepAliveInterval;
  final int keepAliveMaxLifetime;
  final bool leaseEnable;
  final ReactivePayload? payload;

  SetupFrame(
    this.header,
    this.metadataMimeType,
    this.dataMimeType,
    this.keepAliveInterval,
    this.keepAliveMaxLifetime,
    this.leaseEnable, {
    this.payload,
  });

  @override
  String toString() {
    return 'SetupFrame(header: $header, metadataMimeType: $metadataMimeType, dataMimeType: $dataMimeType, keepAliveInterval: $keepAliveInterval, keepAliveMaxLifetime: $keepAliveMaxLifetime, leaseEnable: $leaseEnable)';
  }
}

class LeaseFrame {
  final FrameHeader header;
  final int timeToLive;
  final int requests;

  LeaseFrame(this.header, this.timeToLive, this.requests);

  @override
  String toString() => 'LeaseFrame(header: $header, timeToLive: $timeToLive, requests: $requests)';
}

class KeepAliveFrame {
  final FrameHeader header;
  final int lastReceivedPosition;
  final bool respond;
  final ReactivePayload? payload;

  KeepAliveFrame(this.header, this.lastReceivedPosition, this.respond, {this.payload});

  @override
  String toString() {
    return 'KeepAliveFrame(header: $header, lastReceivedPosition: $lastReceivedPosition, respond: $respond, payload: $payload)';
  }
}

class ErrorFrame {
  final FrameHeader header;
  final int code;
  final Uint8List message;

  ErrorFrame(this.header, this.message, this.code);

  @override
  String toString() => 'ErrorFrame(header: $header, code: $code, message: $message)';
}

class RequestResponseFrame {
  final FrameHeader header;
  final ReactivePayload? payload;

  RequestResponseFrame(this.header, {this.payload});

  @override
  String toString() => 'RequestResponseFrame(header: $header, payload: $payload)';
}

class RequestFNFFrame {
  final FrameHeader header;
  final ReactivePayload? payload;

  RequestFNFFrame(this.header, {this.payload});

  @override
  String toString() => 'RequestFNFFrame(header: $header, payload: $payload)';
}

class RequestStreamFrame {
  final FrameHeader header;
  final int? initialRequestCount;
  final ReactivePayload? payload;

  RequestStreamFrame(this.header, {this.initialRequestCount, this.payload});

  @override
  String toString() => 'RequestStreamFrame(header: $header, initialRequestCount: $initialRequestCount, payload: $payload)';
}

class RequestChannelFrame {
  final FrameHeader header;
  final int? initialRequestCount;
  final ReactivePayload? payload;

  RequestChannelFrame(this.header, {this.initialRequestCount, this.payload});

  @override
  String toString() => 'RequestChannelFrame(header: $header, initialRequestCount: $initialRequestCount, payload: $payload)';
}

class RequestNFrame {
  final FrameHeader header;
  final int? count;

  RequestNFrame(this.header, {this.count});

  @override
  String toString() => 'RequestNFrame(header: $header, count: $count)';
}

class MetadataPushFrame {
  final FrameHeader header;
  final ReactivePayload? payload;

  MetadataPushFrame(this.header, {this.payload});

  @override
  String toString() => 'MetadataPushFrame(header: $header, payload: $payload)';
}

class PayloadFrame {
  final FrameHeader header;
  final bool completed;
  final bool follow;
  final ReactivePayload? payload;

  PayloadFrame(this.header, this.completed, this.follow, {this.payload});

  @override
  String toString() => 'PayloadFrame(header: $header, completed: $completed, follow: $follow, payload: $payload)';
}

class ResumeFrame {
  final FrameHeader header;
  final int lastReceivedServerPosition;
  final int firstAvailableClientPosition;
  final Uint8List token;

  ResumeFrame(this.header, this.lastReceivedServerPosition, this.firstAvailableClientPosition, this.token);

  @override
  String toString() => 'ResumeFrame(header: $header, lastReceivedServerPosition: $lastReceivedServerPosition, firstAvailableClientPosition: $firstAvailableClientPosition)';
}

class ResumeOkFrame {
  final FrameHeader header;
  final int lastReceivedClientPosition;

  ResumeOkFrame(this.header, this.lastReceivedClientPosition);

  @override
  String toString() => 'ResumeOkFrame(header: $header, lastReceivedClientPosition: $lastReceivedClientPosition)';
}
