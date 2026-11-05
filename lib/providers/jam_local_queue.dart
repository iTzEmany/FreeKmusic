import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../data/settings/settings_store.dart' show SavedPlayback;
import '../services/audio/codecore_audio_handler.dart';
import '../services/audio/playback_persistence.dart';
import '../services/audio/resume_point.dart' show isPastEnd;
import 'player_providers.dart';
import 'settings_providers.dart';
import 'shuffle_plus_providers.dart' show ShuffleMode;

/// A guest's own queue from before the Jam (R-90), kept in memory and aside on disk,
/// and put back when the Jam is left. A host keeps its queue: only the shuffle mode.
class JamLocalQueue {
  JamLocalQueue(this._ref, this._unplayed);

  /// A getter, not the Ref: a rebuilt provider gets a new Ref and the first goes unmounted.
  final Ref Function() _ref;

  /// Our part of «Coda insieme» not yet played (the Jam's `_part.unplayed`).
  final List<int> Function() _unplayed;

  /// The guest's own queue from before the Jam (R-90); null for a host.
  ({List<int> ids, int index, Duration position})? saved;
  PlaybackPersistence? _persistence;
  CodecoreAudioHandler? _localHandler;
  ShuffleMode? _mode;

  /// The part last written aside: a new write only when it changes.
  List<int> _asidePart = const [];

  /// Keeps the local queue, track and position on disk and in memory.
  Future<void> save() async {
    final handler = _ref().read(audioHandlerProvider);
    _localHandler = handler;
    _mode = _shuffleMode(handler);
    // The live position: a paused player emits none, so the stream can be 0.
    var position = handler.playbackState.value.position;
    // audio_service extrapolates a playing position: past the track's end it is stale.
    if (isPastEnd(position, handler.currentTrack?.durationMs ?? 0)) position = Duration.zero;
    saved = (
      ids: List.of(handler.queueIds),
      index: handler.currentIndex < 0 ? 0 : handler.currentIndex,
      position: position,
    );
    await (_persistence = _ref().read(playbackPersistenceProvider))
        ?.hold(position);
    await _keepAside();
  }

  /// A host keeps its queue; only the shuffle mode is put back (the Jam's player state drops «+»).
  Future<void> saveMode() async {
    _localHandler = _ref().read(audioHandlerProvider);
    _mode = _shuffleMode(_localHandler!);
    _persistence = _ref().read(playbackPersistenceProvider);
    await _keepAside();
  }

  /// The Jam's part changed: write it aside again, only when it differs from the last write.
  void refreshAside() {
    if (saved == null) return;
    if (!listEquals(_unplayed(), _asidePart)) unawaited(_keepAside());
  }

  ShuffleMode _shuffleMode(CodecoreAudioHandler h) => !h.shuffleEnabled
      ? ShuffleMode.off
      : _ref().read(settingsProvider).shufflePlus
          ? ShuffleMode.plus
          : ShuffleMode.shuffle;

  /// What leaving gives back: our part not yet played, from its first track (D-209),
  /// else the queue as it was; null for a host.
  ({List<int> ids, int index, Duration position})? get _toGive {
    final s = saved;
    if (s == null) return null;
    final part = _unplayed();
    return part.isEmpty ? s : (ids: part, index: 0, position: Duration.zero);
  }

  /// The same, on disk, for an app closed in the middle of the Jam (D-341).
  Future<void> _keepAside() async {
    final mode = _mode;
    if (mode == null) return;
    final give = _toGive;
    _asidePart = _unplayed();
    final q = give == null ? (ids: const <int>[], index: 0) : savedQueue(give.ids, give.index);
    await _persistence?.keepAside(
      SavedPlayback(
        queueIds: q.ids,
        index: q.index,
        positionMs: give?.position.inMilliseconds ?? 0,
        shuffle: mode != ShuffleMode.off,
      ),
      plus: mode == ShuffleMode.plus,
    );
  }

  /// Puts the queue back as it was, paused, and lets the disk follow again.
  /// A Jam left in «Coda insieme» gives back our part not yet played, from its first
  /// track (D-209); never an empty queue when there was one before (invariant 6).
  /// The shuffle mode comes back as it was (D-342).
  Future<void> restore() async {
    final mode = _mode;
    _mode = null;
    _asidePart = const [];
    if (mode == null) return;
    final give = _toGive;
    saved = null;
    final handler = _localHandler;
    final persistence = _persistence;
    _persistence = null;
    if (handler != null) {
      handler.setShuffleAndRepeat(shuffle: mode != ShuffleMode.off, repeat: handler.repeatMode);
      final plus = mode == ShuffleMode.plus;
      if (_ref().read(settingsProvider).shufflePlus != plus) {
        _ref().read(settingsProvider.notifier).update((c) => c.copyWith(shufflePlus: plus));
      }
    }
    if (give != null) {
      try {
        await handler?.restore(give.ids, give.index, give.position);
      } on Object catch (e, st) {
        AppLog.w('jam: could not restore the local queue', e, st);
      }
      persistence?.release(give.position);
      await persistence?.flush();
    }
    await persistence?.dropAside();
  }
}
