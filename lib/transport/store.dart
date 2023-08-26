import 'dart:collection';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'state.dart';

abstract interface class ReactiveFrameStore {
  Queue<Uint8List> get();

  void add(Uint8List frame);

  void save(Queue<Uint8List> frames, {required bool rewrite});

  void clear();

  bool get isEmpty;
}

abstract interface class ReactiveResumeServerStore {
  ReactiveResumeState? get(Uint8List token);

  void save(ReactiveResumeState state);

  void remove(Uint8List token);
}

abstract interface class ReactiveResumeClientStore {
  List<ReactiveResumeState> list(String address);

  void add(String address, ReactiveResumeState state);

  void removeAddress(String address);

  void removeState(String address, Uint8List token);
}

class LocalReactiveFrameStore implements ReactiveFrameStore {
  final _frames = Queue<Uint8List>();

  @override
  Queue<Uint8List> get() => _frames;

  @override
  void add(Uint8List frame) => _frames.add(frame);

  @override
  void save(Queue<Uint8List> frames, {required bool rewrite}) {
    if (rewrite) _frames.clear();
    _frames.addAll(frames);
  }

  @override
  void clear() => _frames.clear();

  @override
  bool get isEmpty => _frames.isEmpty;
}

class LocalReactiveResumeServerStore implements ReactiveResumeServerStore {
  final _states = <Uint8List, ReactiveResumeState>{};

  @override
  ReactiveResumeState? get(Uint8List token) {
    return _states[token];
  }

  @override
  void remove(Uint8List token) {
    _states.remove(token);
  }

  @override
  void save(ReactiveResumeState state) {
    _states[state.token] = state;
  }
}

class LocalReactiveResumeClientStore implements ReactiveResumeClientStore {
  final _states = <String, List<ReactiveResumeState>>{};

  @override
  void add(String address, ReactiveResumeState state) {
    final current = _states[address];
    if (current == null) {
      _states[address] = [state];
      return;
    }
    current.add(state);
  }

  @override
  List<ReactiveResumeState> list(String address) {
    return _states[address] ?? [];
  }

  @override
  void removeAddress(String address) {
    _states.remove(address);
  }

  @override
  void removeState(String address, Uint8List token) {
    const equality = ListEquality();
    _states[address]?.removeWhere((element) => equality.equals(element.token, token));
  }
}
