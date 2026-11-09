import '../audio/online_entries.dart' show isOnlineId;

/// Where suggestions go in the play order [items]: indices in the list as it
/// will be after inserting them, ascending.
///
/// [playedSinceLast] counts the library songs that have started since the
/// last suggestion, the current one included; a suggestion comes after
/// [every] − 1 of them (every 4: three of yours, then one suggested). Online
/// ids already after the current song are filled slots and count towards
/// [max]. [skip] entries right after the current song (the user's queue
/// block) are passed over: slots start after them. A slot is never past the end: a suggestion is never the last thing.
List<int> plusPlan(
  List<int> items,
  int currentIndex,
  int every, {
  int playedSinceLast = 1,
  int max = 3,
  int skip = 0,
}) {
  final plan = <int>[];
  if (currentIndex < 0 || currentIndex >= items.length) return plan;
  var count = playedSinceLast, filled = 0, pos = currentIndex + skip;
  for (var i = currentIndex + 1 + skip; i < items.length && filled < max; i++) {
    pos++;
    if (isOnlineId(items[i])) {
      count = 0;
      filled++;
    } else if (count >= every - 1) {
      plan.add(pos++);
      filled++;
      count = 1;
    } else {
      count++;
    }
  }
  return plan;
}
