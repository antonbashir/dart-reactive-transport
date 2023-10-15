import 'dart:typed_data';

const messagePackMimeType = 'application/message-pack';
const octetStreamMimeType = 'application/octet-stream';
const textMimeType = 'application/text';
final emptyBytes = Uint8List.fromList([]);

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

const reactiveProtocolMajorVersion = 1;
const reactiveProtocolMinorVersion = 0;

const reactiveInfinityRequestsCount = 2147483647;

const reactiveStreamIdMask = 0x7FFFFFFF;
const reactiveClientInitialStreamId = -1;
const reactiveServerInitialStreamId = 0;
const reactiveStreamIdIncrement = 2;

const reactiveRoutingKey = "method";

const reactiveFrameLengthFieldSize = 3;
const reactiveMetadataLengthFieldSize = 3;
const reactiveFrameHeaderSize = 9;