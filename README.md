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

