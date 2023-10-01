import 'dart:typed_data';

import 'exception.dart';

const preferInlinePragma = "vm:prefer-inline";
const reactiveFrameReserved = 0x00;
const reactiveFrameSetup = 0x01;
const reactiveFrameLease = 0x02;
const reactiveFrameKeepalive = 0x03;
const reactiveFrameRequestResponse = 0x04;
const reactiveFrameRequestFnf = 0x05;
const reactiveFrameRequestStream = 0x06;
const reactiveFrameRequestChannel = 0x07;
const reactiveFrameRequestN = 0x08;
const reactiveFrameCancel = 0x09;
const reactiveFramePayload = 0x0A;
const reactiveFrameError = 0x0B;
const reactiveFrameMetadataPush = 0x0C;
const reactiveFrameResume = 0x0D;
const reactiveFrameResumeOk = 0x0E;
const reactiveFrameExt = 0x3F;

const reactiveFrameHeaderFlagIgnore = 0x200;
const reactiveFrameHeaderFlagMetadata = 0x100;
const reactiveFrameHeaderFlagFollow = 0x80;
const reactiveFrameHeaderFlagComplete = 0x40;
const reactiveFrameHeaderFlagNext = 0x20;

const reactiveFrameSetupFlagResume = 0x80;
const reactiveFrameSetupFlagLease = 0x40;

const reactiveFrameKeepAliveFlagRespond = 0x80;

String frame(int id) {
  switch (id) {
    case reactiveFrameReserved:
      return "Reserved";
    case reactiveFrameSetup:
      return "Setup";
    case reactiveFrameLease:
      return "Lease";
    case reactiveFrameKeepalive:
      return "Keepalive";
    case reactiveFrameRequestResponse:
      return "RequestResponse";
    case reactiveFrameRequestFnf:
      return "RequestFnf";
    case reactiveFrameRequestStream:
      return "RequestStream";
    case reactiveFrameRequestChannel:
      return "RequestChannel";
    case reactiveFrameRequestN:
      return "RequestN";
    case reactiveFrameCancel:
      return "Cancel";
    case reactiveFramePayload:
      return "Payload";
    case reactiveFrameError:
      return "Error";
    case reactiveFrameMetadataPush:
      return "MetadataPush";
    case reactiveFrameResume:
      return "Resume";
    case reactiveFrameResumeOk:
      return "ResumeOk";
    case reactiveFrameExt:
      return "Ext";
  }
  return "Unknown";
}

const reactiveProtocolMajorVersion = 1;
const reactiveProtocolMinorVersion = 0;

const infinityRequestsCount = 2147483647;

const reactiveStreamIdMask = 0x7FFFFFFF;
const reactiveClientInitialStreamId = -1;
const reactiveServerInitialStreamId = 0;
const reactiveStreamIdIncrement = 2;

class ReactiveExceptions {
  ReactiveExceptions._();

  static const applicationErrorCode = 0x00000201;

  static connectionError(String message) => ReactiveException(
        0x00000101,
        message,
      );

  static const invalidSetup = ReactiveException(
    0x00000001,
    "The Setup frame is invalid",
  );
  static const unsupportedSetup = ReactiveException(
    0x00000002,
    "Some (or all) of the parameters specified by the client are unsupported by the server",
  );
  static const rejectedSetup = ReactiveException(
    0x00000003,
    "The server rejected the setup, it can specify the reason in the payload",
  );
  static const rejectedResume = ReactiveException(
    0x00000004,
    "The server rejected the resume, it can specify the reason in the payload",
  );

  static const connectionClose = ReactiveException(
    0x00000102,
    "The connection is being closed",
  );
  static const rejected = ReactiveException(
    0x00000202,
    "Despite being a valid request, the Responder decided to reject it",
  );
  static const canceled = ReactiveException(
    0x00000203,
    "The Responder canceled the request but may have started processing it",
  );
  static const invalid = ReactiveException(
    0x00000204,
    "The request is invalid",
  );
  static const reservedExtension = ReactiveException(
    0xFFFFFFFF,
    "Reserved for Extension",
  );
}

const messagePackMimeType = 'application/message-pack';
const octetStreamMimeType = 'application/octet-stream';
const textMimeType = 'application/text';

const routingKey = "method";

final emptyBytes = Uint8List.fromList([]);

const reactiveFrameLengthFieldSize = 3;
const reactiveMetadataLengthFieldSize = 3;
const reactiveFrameHeaderSize = 9;

const reactiveChannelClosedException = "Channel closed. Requesting is not available";
