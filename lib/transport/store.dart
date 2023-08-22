import 'dart:collection';
import 'dart:typed_data';

abstract interface class ReactiveResumeStore {
  Queue<Uint8List> load();

  void add(Uint8List frame);

  void save(Queue<Uint8List> frames, {required bool rewrite});

  void clear();

  bool get isEmpty;
}

class LoaclReactiveResumeStore implements ReactiveResumeStore {
  final _frames = Queue<Uint8List>();

  @override
  Queue<Uint8List> load() => _frames;

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
