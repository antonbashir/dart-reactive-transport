import 'dart:typed_data';
import 'constants.dart';

extension BytesExtensions<T> on Uint8List {
  @pragma(preferInlinePragma)
  List<Uint8List> chunks(int size) {
    var index = 0;
    var resultIndex = 0;
    final result = List.generate((length / size).ceil(), (_) => emptyBytes);
    while (index < length) result[resultIndex++] = sublist(index, (index += size));
    return result;
  }
}
