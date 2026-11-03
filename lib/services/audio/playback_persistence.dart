import 'dart:async';

import '../../core/app_log.dart';
import '../../data/settings/settings_store.dart';
import 'codecore_audio_handler.dart';
import 'online_entries.dart';

/// The queue as saved: online entries do not survive a restart, so they are
/// dropped. [index] points to the current library track, or, when the current
/// one is online, to the library track that followed it.
({List<int> ids, int index}) savedQueue(List<int> ids, int index) {
  final kept = [
    for (final id in ids)
      if (!isOnlineId(id)) id,
  ];
  if (kept.isEmpty) return (ids: kept, index: 0);
  var at = 0;
  for (var i = 0; i < ids.length && i < index; i++) {
    if (!isOnlineId(ids[i])) at++;
  }
  return (ids: kept, index: at.clamp(0, kept.length - 1));
}

/// Debounced (2 s) save of queue/position/volume so playback can resume.
class PlaybackPersistence {
  PlaybackPersistence(this._handler, this._store);

  final CodecoreAudioHandler _handler;
  final SettingsStore _store;
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _timer;
  double _volume = 1.0;
  Duration _position = Duration.zero;
  bool _held = false;

  /// Restores the saved queue paused at the saved position. A copy kept aside
  /// by a Jam left open (D-341) comes back instead, then goes. Returns whether
  /// Shuffle+ was on in that copy (null: no copy).
  Future<bool?> restore() async {
    final s = _store.readPlayback();
    ({SavedPlayback queue, bool plus})? aside;
    try {
      aside = _store.readJamAside();
    } on Object catch (e, st) {
      AppLog.w('jam: unreadable queue kept aside', e, st);
    }
    await dropAside();
    _volume = s.volume;
    await _handler.setVolume(s.volume);
    // A copy with no queue (a host) carries only the shuffle mode.
    final q = aside != null && aside.queue.queueIds.isNotEmpty ? aside.queue : s;
    _handler.setShuffleAndRepeat(shuffle: aside?.queue.shuffle ?? s.shuffle, repeat: s.repeat);
    if (q.queueIds.isEmpty) return aside?.plus;
    await _handler.restore(q.queueIds, q.index, Duration(milliseconds: q.positionMs));
    if (aside != null) {
      _position = Duration(milliseconds: q.positionMs);
      await flush(); // the disk follows the queue now back
    }
    return aside?.plus;
  }

  /// Keeps [q] aside for a restart in the middle of a Jam (D-341).
  Future<void> keepAside(SavedPlayback q, {required bool plus}) async {
    try {
      await _store.writeJamAside(q, plus: plus);
    } on Object catch (e, st) {
      AppLog.w('jam: could not keep the queue aside', e, st);
    }
  }

  Future<void> dropAside() async {
    try {
      await _store.clearJamAside();
    } on Object catch (e, st) {
      AppLog.w('jam: could not drop the queue kept aside', e, st);
    }
  }

  void start() {
    _subs
      ..add(_handler.positionStream.listen((p) {
        _position = p;
        _schedule();
      }))
      ..add(_handler.queueChanges.listen((_) => _schedule()))
      ..add(_handler.currentTrackStream.listen((_) => _schedule()));
  }

  void setVolume(double v) {
    _volume = v;
    _schedule();
  }

  void _schedule() {
    _timer ??= Timer(const Duration(seconds: 2), () {
      _timer = null;
      unawaited(flush());
    });
  }

  /// Saves now, then keeps the disk as it is until [release]: a Jam guest's
  /// queue from before the Jam is what a restart in the middle of it finds.
  Future<void> hold(Duration position) async {
    _position = position;
    final f = flush(); // reads _held synchronously: a release meanwhile stays
    _held = true;
    await f;
  }

  /// The disk follows again, from [position] (where the restored track waits).
  void release(Duration position) {
    _position = position;
    _held = false;
  }

  Future<void> flush() async {
    if (_held) return;
    try {
      final q = savedQueue(
          _handler.queueIds, _handler.currentIndex < 0 ? 0 : _handler.currentIndex);
      await _store.writePlayback(SavedPlayback(
        queueIds: q.ids,
        index: q.index,
        positionMs: _position.inMilliseconds,
        volume: _volume,
        shuffle: _handler.shuffleEnabled,
        repeat: _handler.repeatMode,
      ));
    } on Object catch (e, st) {
      AppLog.w('persist playback failed', e, st);
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
  }
}
