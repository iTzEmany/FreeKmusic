import 'dislike_store.dart';

/// The one filter for «Non mi piace» (D-437, D-468): a blocked artist is never
/// suggested; a blocked song only when it shows up in the radio of at least
/// [minSeeds] seeds within their first [topRows] rows. Pure: no I/O.
class SuggestionGate {
  SuggestionGate(this.store);

  static const minSeeds = 2;
  static const topRows = 10;

  final DislikeStore store;

  /// Waits for the store file (and the migration from the log).
  Future<void> load() => store.load();

  /// Whether a suggestion by [artistKey] with id [videoId] may be suggested.
  /// [positions]: 1-based row of the song in each seed's radio where it appeared.
  bool allows(String videoId, String artistKey, Iterable<int> positions) {
    if (store.artistBlocked(artistKey)) return false;
    if (!store.trackBlocked(videoId)) return true;
    return positions.where((p) => p <= topRows).length >= minSeeds;
  }
}
