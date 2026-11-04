/// When the radio may be asked: at most once a minute, and not for 15 minutes
/// after a 429. Shared by Shuffle+ and the genre mix so that both obey one
/// policy.
class RadioGate {
  RadioGate({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const minGap = Duration(minutes: 1);
  static const pause = Duration(minutes: 15);

  final DateTime Function() _now;

  /// When the radio was last asked (set by [asked]).
  DateTime? lastRadio;

  /// End of the pause after a 429 (set by [trip]).
  DateTime? pausedUntil;

  /// True while the pause after a 429 lasts.
  bool get rateLimited => pausedUntil?.isAfter(_now()) ?? false;

  /// The gap since the last request has passed and no pause is running.
  bool get canAsk => nextAsk == null;

  /// When [canAsk] turns true; null when it already is.
  DateTime? get nextAsk {
    final now = _now();
    final at = [?lastRadio?.add(minGap), ?pausedUntil].where(now.isBefore);
    return at.isEmpty ? null : at.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// A radio request is about to be made.
  void asked() => lastRadio = _now();

  /// The radio answered 429: stop asking for [pause].
  void trip() => pausedUntil = _now().add(pause);
}
