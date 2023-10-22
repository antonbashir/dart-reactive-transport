import 'package:test/test.dart';

import 'backpressure.dart';
import 'custom.dart';
import 'errors.dart';
import 'fragmentation.dart';
import 'interaction.dart';
import 'keepalive.dart';
import 'lease.dart';
import 'shutdown.dart';

void main() {
  group("[interaction]", interaction);
  group("[fragmentation]", fragmentation);
  group("[errors]", errors);
  group("[custom]", custom);
  group("[backpressure]", backpressure);
  group("[keepalive]", keepalive);
  group("[lease]", lease);
  group("[shutdown]", shutdown);
}
