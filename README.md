# Introduction

<img src="dart-logo.png"  height="80" />
<img src="rsocket.svg"  height="80" />


Dart reactive transport is an implementation of the [RSocket](https://rsocket.io/) protocol over the [IOUring](https://github.com/antonbashir/dart-iouring-transport) transport.

This library doesn't implement all RSocket operations. It includes only REQUEST CHANNEL.
- [Introduction](#introduction)
- [Features](#features)
  - [Implemented](#implemented)
  - [Unimplemented (and won't be implemented)](#unimplemented-and-wont-be-implemented)
- [Installation \& Usage](#installation--usage)
  - [Quick Start](#quick-start)
  - [Sample](#sample)
- [API](#api)
  - [ReactiveChannel](#reactivechannel)
    - [Properties:](#properties)
    - [Methods:](#methods)
  - [ReactiveSubscriber](#reactivesubscriber)
    - [Methods:](#methods-1)
  - [ReactiveProducer](#reactiveproducer)
    - [Methods:](#methods-2)
  - [ReactiveTransport](#reactivetransport)
    - [Method: `ReactiveTransport.shutdown`](#method-reactivetransportshutdown)
    - [Method: `ReactiveTransport.serve`](#method-reactivetransportserve)
    - [Method: `ReactiveTransport.connect`](#method-reactivetransportconnect)
- [Performance](#performance)
- [Limitations](#limitations)
- [Contribution](#contribution)

# Features

## Implemented

* client and server two-sided channels
* backpressure
* lease
* graceful shutdown
* fragmentation
* multicodec

## Unimplemented (and won't be implemented)

* resume
* retry
* fire and forget
* request response
* metadata push
* request stream
* rxdart
* non-linux platform

# Installation & Usage

## Quick Start

1. Initiate a Dart project with pubspec.yaml.
2. Append the following section to your dependencies:

```yaml
  iouring_transport:
    git:
      url: https://github.com/antonbashir/dart-iouring-transport/
      path: dart
  reactive_transport:
    git: 
      url: https://github.com/antonbashir/dart-reactive-transport/
```

3. Run `dart pub get`.
4. Refer to the [API](#api) for implementation details. Enjoy!

## Sample

Simple example can be found [here](https://github.com/antonbashir/dart-reactive-sample).

# API

## ReactiveChannel

It handles events related to error handling, payload processing, subscription, etc.

### Properties:

- `key` (String): A unique identifier for the channel.
- `configuration` (ReactiveChannelConfiguration): Configuration settings for the channel.

### Methods:

- `onError`: Handles error events.
- `onPayload`: Handles payload events.
- `onRequest`: Handles request events.
- `onSubscribe`: Handles subscription events.
- `onComplete`: Handles completion events.
- `onCancel`: Handles cancellation events.

## ReactiveSubscriber

The main class for reactive subscribers using the Iouring Transport library.

### Methods:

- `subscribe`: Subscribes to a functional channel and receives messages as they arrive.
- `subscribeCustom`: Subscribes to a specified channel and receives messages as they arrive.

## ReactiveProducer

The main class for reactive producer using the Iouring Transport library.

### Methods: 

- `payload`: Schedules a payload to be sent through the transport.
- `error`: Schedules an error message to be sent through the transport.
- `cancel`: Cancels a currently scheduled payload or error stream.
- `complete`: Completes the stream.
- `request`: Requests a specified number of messages to be sent through the transport.
- `unbound`: Requests an unbounded number of messsages to be sent through the transport.

## ReactiveTransport

The main class for reactive transport using the Iouring Transport library.

### Method: `ReactiveTransport.shutdown`

Shuts down the reactive transport and its associated server and client connections.

- Parameters:
  - `transport`: (optional) If `true`, also shuts down the underlying transport object.
    - Type: `bool`
- Returns: `Future<void>`

### Method: `ReactiveTransport.serve`

Starts a new server that listens on the specified `address` and `port`.

- Parameters:
  - `address`: Internet address to listen on.
    - Type: `InternetAddress`
  - `port`: Port to listen on.
    - Type: `int`
  - `acceptor`: Function called for each incoming connection.
    - Type: `void Function(ReactiveServerConnection connection)`
  - `onError`: (optional) Callback to handle errors.
    - Type: `void Function(ReactiveException exception)?`
  - `onShutdown`: (optional) Callback to be called when the server shuts down.
    - Type: `void Function()?`
  - `tcpConfiguration`: (optional) TCP server configuration.
    - Type: `TransportTcpServerConfiguration`
  - `brokerConfiguration`: (optional) Broker configuration.
    - Type: `ReactiveBrokerConfiguration`
  - `leaseConfiguration`: (optional) Lease configuration.
    - Type: `ReactiveLeaseConfiguration`
- Returns: `Future<void>`

### Method: `ReactiveTransport.connect`

Connects a new client to the server at the specified `address` and `port`.

- Parameters:
  - `address`: Internet address of the server.
    - Type: `InternetAddress`
  - `port`: Port of the server.
    - Type: `int`
  - `connector`: Function called for each incoming connection.
    - Type: `void Function(ReactiveClientConnection connection)`
  - `onError`: (optional) Callback to handle errors.
    - Type: `void Function(ReactiveException exception)?`
  - `onShutdown`: (optional) Callback to be called when the client disconnects.
    - Type: `void Function()?`
  - `tcpConfiguration`: (optional) TCP client configuration.
    - Type: `TransportTcpClientConfiguration`
  - `setupConfiguration`: (optional) Setup configuration.
    - Type: `ReactiveSetupConfiguration`
  - `brokerConfiguration`: (optional) Broker configuration.
    - Type: `ReactiveBrokerConfiguration`
- Returns: `Future<ReactiveClientConnection>`

# Performance

To be added: Benchmarking results on the preferred machine.

Most recent benchmark results:

- Messages per Second: 100k-150k per isolate

# Limitations

- Only compatible with Linux.
- Not tested in a production environment. The current version is developed and tested with unit tests, so bugs may be present.

# Contribution

Currently maintainer hasn't resources on maintain pull requests but issues are welcome.

Every issue will be observed, discussed and applied or closed if this project does not need it.
