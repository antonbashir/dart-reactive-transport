import 'dart:typed_data';

import 'configuration.dart';

abstract interface class ResumeState {
  ReactiveSetupConfiguration get setupConfiguration;
  bool get empty;
  Uint8List get token;
}

class ReactiveResumeClientState implements ResumeState {
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

class ReactiveResumeServerState implements ResumeState {
  late final ReactiveSetupConfiguration setupConfiguration;
  late final Uint8List token;
  late final int lastReceivedClientPosition;

  bool _empty = true;
  bool get empty => _empty;

  ReactiveResumeServerState();
}
