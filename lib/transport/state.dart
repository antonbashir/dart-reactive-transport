import 'dart:collection';
import 'dart:typed_data';

import 'configuration.dart';
import 'store.dart';

abstract interface class ReactiveResumeState {
  ReactiveSetupConfiguration get setupConfiguration;
  bool get empty;
  Uint8List get token;
  void save(Uint8List frame);
  Queue<Uint8List> get();
  void onReceive(Uint8List frame);
}

class ReactiveResumeClientState implements ReactiveResumeState {
  final ReactiveSetupConfiguration setupConfiguration;
  final Uint8List token;
  final ReactiveResumeStore store;

  bool _empty = true;
  int _lastReceivedServerPosition = 0;
  int _firstAvailableClientPosition = 0;

  @override
  bool get empty => _empty;

  int get lastReceivedServerPosition => _lastReceivedServerPosition;
  int get firstAvailableClientPosition => _firstAvailableClientPosition;

  ReactiveResumeClientState({
    required this.setupConfiguration,
    required this.token,
    required this.store,
  });

  @override
  void save(Uint8List frame) {
    if (store.isEmpty) _firstAvailableClientPosition = frame.length;
    store.add(frame);
  }

  @override
  void onReceive(Uint8List frame) {
    _lastReceivedServerPosition += frame.length;
  }

  @override
  Queue<Uint8List> get() {
    return store.load();
  }
}

class ReactiveResumeServerState implements ReactiveResumeState {
  bool _empty = true;
  int _lastReceivedClientPosition = 0;

  late ReactiveSetupConfiguration _setupConfiguration;
  late Uint8List _token;

  @override
  bool get empty => _empty;

  @override
  ReactiveSetupConfiguration get setupConfiguration => _setupConfiguration;

  @override
  Uint8List get token => _token;

  int get lastReceivedClientPosition => _lastReceivedClientPosition;

  ReactiveResumeServerState();

  @override
  void save(Uint8List frame) {
    throw UnimplementedError();
  }

  @override
  void onReceive(Uint8List frame) {
    _lastReceivedClientPosition += frame.length;
  }

  @override
  Queue<Uint8List> get() {
    throw UnimplementedError();
  }
}
