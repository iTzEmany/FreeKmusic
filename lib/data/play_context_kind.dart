/// Where a queue or a listen was started from.
// .index is stored (prefs lastContextKind, DB plays.context, synced listens): only append values, never reorder.
enum PlayContextKind {
  album,
  artist,
  playlist,
  favorites,
  library,
  search,
  podcast,
  radio,
  daylist;

  /// The one decoding of a stored index: null, or one this version does not know (a newer one, a synced listen), is `library`.
  static PlayContextKind fromIndex(int? i) =>
      i != null && i >= 0 && i < values.length ? values[i] : library;
}
