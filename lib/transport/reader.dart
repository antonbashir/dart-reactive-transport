import 'dart:convert';
import 'dart:typed_data';

import 'constants.dart';
import 'buffer.dart';
import 'frame.dart';
import 'payload.dart';

class ReactiveReader {
  FrameHeader readFrameHeader(ReactiveReadBuffer buffer) {
    final frameLength = buffer.readInt24() ?? 0;
    final streamId = buffer.readInt32() ?? 0;
    var type = 0;
    var meta = false;
    final frameTypeByte = buffer.readInt8();
    if (frameTypeByte != null) {
      type = frameTypeByte >> 2;
      meta = (frameTypeByte & 0x01) == 1;
    }
    final flags = buffer.readInt8() ?? 0;
    return FrameHeader(frameLength, streamId, type, flags, meta);
  }

  SetupFrame readSetupFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    var delta = buffer.readerIndex - reactiveFrameHeaderSize;
    var resumeEnable = (header.flags & 0x80) > 0;
    final leaseEnable = (header.flags & 0x40) > 0;
    buffer.readInt16();
    buffer.readInt16();
    var keepAliveInterval = buffer.readInt32() ?? 0;
    var keepAliveMaxLifetime = buffer.readInt32() ?? 0;
    var resumeToken;
    if (resumeEnable) {
      var resumeTokenLength = buffer.readInt16();
      if (resumeTokenLength != null) {
        var tokenU8Array = buffer.readBytes(resumeTokenLength);
        if (tokenU8Array.isNotEmpty) {
          resumeToken = utf8.decode(tokenU8Array);
        }
      }
    }
    var metadataMimeTypeLength = buffer.readInt8();
    var metadataMimeType;
    if (metadataMimeTypeLength != null) {
      var metadataMimeTypeU8Array = buffer.readBytes(metadataMimeTypeLength);
      if (metadataMimeTypeU8Array.isNotEmpty) {
        metadataMimeType = utf8.decode(metadataMimeTypeU8Array);
      }
    }
    var dataMimeTypeLength = buffer.readInt8();
    var dataMimeType;
    if (dataMimeTypeLength != null) {
      var dataMimeTypeU8Array = buffer.readBytes(dataMimeTypeLength);
      if (dataMimeTypeU8Array.isNotEmpty) {
        dataMimeType = utf8.decode(dataMimeTypeU8Array);
      }
    }
    delta = buffer.readerIndex - delta;
    final payload = _readPayload(buffer, header.metaPresent, header.frameLength + reactiveFrameLengthFieldSize - delta);
    return SetupFrame(
      header,
      metadataMimeType,
      dataMimeType,
      keepAliveInterval,
      keepAliveMaxLifetime,
      leaseEnable,
      payload: payload,
      resumeToken: resumeToken,
    );
  }

  LeaseFrame readLeaseFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    final timeToLive = buffer.readInt32() ?? 0;
    final numberOfRequests = buffer.readInt32() ?? 0;
    return LeaseFrame(header, timeToLive, numberOfRequests);
  }

  KeepAliveFrame readKeepAliveFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    var delta = buffer.readerIndex - reactiveFrameHeaderSize;
    var lastReceivedPosition = buffer.readInt32() ?? 0;
    delta = buffer.readerIndex - delta;
    var payload;
    final dataLength = header.frameLength + reactiveFrameLengthFieldSize - delta;
    if (dataLength > 0) {
      payload = _readPayload(buffer, header.metaPresent, dataLength);
    }
    return KeepAliveFrame(header, lastReceivedPosition, (header.flags & 0x80) > 0, payload: payload);
  }

  ErrorFrame readErrorFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    var delta = buffer.readerIndex - reactiveFrameHeaderSize;
    final code = buffer.readInt32()!;
    delta = buffer.readerIndex - delta;
    final dataLength = header.frameLength + reactiveFrameLengthFieldSize - delta;
    var message = emptyBytes;
    if (dataLength > 0) {
      message = buffer.readUint8List(dataLength);
    }
    return ErrorFrame(header, message, code);
  }

  RequestChannelFrame readRequestChannelFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    var delta = buffer.readerIndex - reactiveFrameHeaderSize;
    final initialRequestN = buffer.readInt32();
    delta = buffer.readerIndex - delta;
    if (header.frameLength > 0) {
      return RequestChannelFrame(
        header,
        initialRequestCount: initialRequestN,
        payload: _readPayload(buffer, header.metaPresent, header.frameLength + reactiveFrameLengthFieldSize - delta),
      );
    }
    return RequestChannelFrame(header, initialRequestCount: initialRequestN);
  }

  RequestNFrame readRequestNFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    return RequestNFrame(header, count: buffer.readInt32());
  }

  PayloadFrame readPayloadFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    if (header.frameLength > 0) {
      return PayloadFrame(
        header,
        (header.flags & 0x40) > 0,
        payload: _readPayload(buffer, header.metaPresent, header.frameLength + reactiveFrameLengthFieldSize - reactiveFrameHeaderSize),
      );
    }
    return PayloadFrame(header, (header.flags & 0x40) > 0);
  }

  ResumeFrame readResumeFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    buffer.readInt16();
    buffer.readInt16();
    var tokenLength = buffer.readInt16() ?? 0;
    var token = tokenLength == 0 ? emptyBytes : Uint8List.fromList(buffer.readBytes(tokenLength));
    final lastReceivedServerPosition = buffer.readInt64() ?? 0;
    final firstAvailableClientPosition = buffer.readInt64() ?? 0;
    return ResumeFrame(header, lastReceivedServerPosition, firstAvailableClientPosition, token);
  }

  ResumeOkFrame readResumeOkFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    buffer.readInt16();
    buffer.readInt16();
    final lastReceivedClientPosition = buffer.readInt64() ?? 0;
    return ResumeOkFrame(header, lastReceivedClientPosition);
  }

  ReactivePayload _readPayload(ReactiveReadBuffer buffer, bool metadataPresent, int dataLength) {
    var metadata = emptyBytes;
    var data = emptyBytes;
    if (metadataPresent) {
      final metadataLength = buffer.readInt24();
      if (metadataLength != null) {
        dataLength = dataLength - reactiveMetadatLengthFieldSize - metadataLength;
        if (metadataLength > 0) {
          metadata = buffer.readUint8List(metadataLength);
        }
      }
    }
    if (dataLength > 0) {
      data = buffer.readUint8List(dataLength);
    }
    return ReactivePayload(metadata, data);
  }
}
