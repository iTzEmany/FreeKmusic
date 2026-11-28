import 'package:codecore/providers/shuffle_plus_providers.dart'
    show ShuffleMode;
import 'package:codecore/services/shuffle_plus/next_shuffle_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const off = ShuffleMode.off,
      sh = ShuffleMode.shuffle,
      plus = ShuffleMode.plus;
  // (current, plusAllowed, neverOff) -> next
  final table = <(ShuffleMode, bool, bool, ShuffleMode)>[
    (off, true, false, sh),
    (off, false, false, sh),
    (off, true, true, sh),
    (off, false, true, sh),
    (sh, true, false, plus),
    (sh, false, false, off),
    (sh, true, true, plus),
    (sh, false, true, sh),
    (plus, true, false, off),
    (plus, false, false, off),
    (plus, true, true, sh),
    (plus, false, true, sh),
  ];
  for (final (cur, allowed, never, next) in table) {
    test('$cur plusAllowed=$allowed neverOff=$never -> $next', () {
      expect(nextShuffleMode(cur, plusAllowed: allowed, neverOff: never), next);
    });
  }
}
