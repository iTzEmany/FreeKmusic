import 'package:flutter_test/flutter_test.dart';

import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/services/online/request_budget.dart' show apiIdentified;

void main() {
  test('enrichMinutes: 7 s per track identified, 40 s anonymous', () {
    expect(kEnrichSecondsIdentified, 7);
    expect(kEnrichSecondsAnonymous, 40);
    final s = apiIdentified ? 7 : 40;
    expect(enrichMinutes(1871), (1871 * s / 60).ceil());
    expect(enrichMinutes(1), 1);
  });
}
