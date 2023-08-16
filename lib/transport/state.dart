import 'dart:typed_data';

import 'configuration.dart';

class ReactiveResumeClientState {
  final ReactiveSetupConfiguration setupConfiguration;
  final Uint8List token;
  final int lastReceivedServerPosition;
  final int firstAvailableClientPosition;
  
  bool _empty = true;
  bool get empty => _empty;

  ReactiveResumeClientState({
    required this.setupConfiguration,
    required this.token,
    required this.lastReceivedServerPosition,
    required this.firstAvailableClientPosition,
  });
}

class ReactiveResumeServerState {
  final ReactiveSetupConfiguration setupConfiguration;
  final Uint8List token;
  final int lastReceivedClientPosition;

  ReactiveResumeServerState({
    required this.setupConfiguration,
    required this.token,
    required this.lastReceivedClientPosition,
  });
}
