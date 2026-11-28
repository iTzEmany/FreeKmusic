import '../../providers/shuffle_plus_providers.dart' show ShuffleMode;

/// The one rule of the shuffle cycle: off → shuffle → Shuffle+ → off.
/// [plusAllowed] false skips Shuffle+. [neverOff] (the Home queue's lock) turns
/// every step towards «off» into «shuffle» (D-767).
ShuffleMode nextShuffleMode(
  ShuffleMode current, {
  required bool plusAllowed,
  required bool neverOff,
}) {
  final down = neverOff ? ShuffleMode.shuffle : ShuffleMode.off;
  return switch (current) {
    ShuffleMode.off => ShuffleMode.shuffle,
    ShuffleMode.shuffle => plusAllowed ? ShuffleMode.plus : down,
    ShuffleMode.plus => down,
  };
}
