import 'dart:typed_data';

import 'configuration.dart';

class ReactiveResumeState {
  final ReactiveSetupConfiguration setupConfiguration;
  final Uint8List token;

  var _lastReceivedServerPosition = 0;
  var _firstAvailableClientPosition = 0;
  var _lastReceivedClientPosition = 0;

  int get lastReceivedServerPosition => _lastReceivedServerPosition;
  int get lastReceivedClientPosition => _lastReceivedClientPosition;
  int get firstAvailableClientPosition => _firstAvailableClientPosition;

  ReactiveResumeState({
    required this.setupConfiguration,
    required this.token,
    int? lastReceivedServerPosition,
    int? lastReceivedClientPosition,
    int? firstAvailableClientPosition,
  })  : this._lastReceivedClientPosition = lastReceivedClientPosition ?? 0,
        this._lastReceivedServerPosition = lastReceivedServerPosition ?? 0,
        this._firstAvailableClientPosition = firstAvailableClientPosition ?? 0;
}
