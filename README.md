# Introduction

Dart reactive transport is an implementation of the [RSocket](https://rsocket.io/) protocol over the [IOUring](https://github.com/antonbashir/dart-iouring-transport) transport.

This library doesn't implement all RSocket operations. It includes only REQUEST CHANNEL.

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

# Performance

To be added: Benchmarking results on the preferred machine.

Most recent benchmark results:

- Messages per Second: 100k-150k per isolate

# Limitations

- Only compatible with Linux.
- Not tested in a production environment. The current version is developed and tested with unit tests, so bugs may be present.

# Further work

1. Benchmarks and optimization
2. SSL

# Contribution

Currently maintainer hasn't resources on maintain pull requests but issues are welcome.

Every issue will be observed, discussed and applied or closed if this project does not need it.
