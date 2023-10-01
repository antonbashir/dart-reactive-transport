import 'dart:typed_data';

class ReactiveAssembler {
  ReactiveAssembler._();

  static Uint8List reassemble(List<Uint8List> fragments) {
    final totalLength = fragments.fold(0, (current, list) => current + list.length);
    final assemble = Uint8List(totalLength);
    var offset = 0;
    for (var fragment in fragments) {
      assemble.setRange(offset, offset + fragment.length, fragment);
      offset += fragment.length;
    }
    return assemble;
  }
}
