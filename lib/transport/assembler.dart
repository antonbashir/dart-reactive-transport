import 'dart:typed_data';

import 'constants.dart';

class ReactiveAssembler {
  ReactiveAssembler._();

  @pragma(preferInlinePragma)
  static Uint8List reassemble(List<Uint8List> fragments) {
    final totalLength = fragments.fold(0, (current, list) => current + list.length);
    final assemble = Uint8List(totalLength);
    var offset = 0;
    for (var fragment in fragments) {
      assemble.setRange(offset, offset + fragment.length, fragment);
      offset += fragment.length;
    }
    fragments.clear();
    return assemble;
  }

  @pragma(preferInlinePragma)
  static List<Uint8List> disassemble(Uint8List payload, int size) {
    var index = 0;
    var resultIndex = 0;
    final result = List.generate((payload.length / size).ceil(), (_) => emptyBytes);
    while (index < payload.length) result[resultIndex++] = payload.sublist(index, (index += size));
    return result;
  }
}
