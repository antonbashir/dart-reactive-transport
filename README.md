# Introduction 

Dart reactive transport is an implementation of the RSocket protocol over the IOUring transport. 

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

#I nstallation & Usage

### Quick Start

1. Initiate a Dart project with pubspec.yaml.
2. Append the following section to your dependencies:

```
  iouring_transport:
    git: 
      url: https://github.com/antonbashir/dart-iouring-transport/
      path: dart
```

3. Run `dart pub get`.
4. Refer to the [API](#api) for implementation details. Enjoy!

## Sample

Simple example can be found [here](https://github.com/antonbashir/dart-iouring-sample).

Reactive transport implementation can be found [here](https://github.com/antonbashir/dart-reactive-transport).


