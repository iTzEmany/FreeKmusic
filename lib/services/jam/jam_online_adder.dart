import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../online/youtube_service.dart';
import '../stream/stream_cache.dart';
import '../stream/stream_key.dart' show displayArtist;
import 'jam_models.dart';

/// Queues online tracks into the Jam from this device: each one downloads into
/// our cache (in parallel), but the `add` commands go out in the order of the
/// calls (D-80), and only once the file is ready. Never throws.
class JamOnlineAdder {
  JamOnlineAdder({
    required this.ownId,
    required this.cache,
    required this.ready,
    required this.send,
    required this.onFailed,
  });

  final String ownId;
  final StreamCache cache;

  /// The preparer's `ready`: the cached file, downloading it if needed.
  final Future<File> Function(String key, YtResult r) ready;
  final Future<JamError?> Function(JamCommand) send;
  final void Function(YtResult r) onFailed;

  var _tail = Future<void>.value();
  final _pinned = <String>{}; // held from the call until the item shows in the queue
  var _disposed = false;

  /// Accepts [r] at once; the item appears when its file is ready.
  void add(YtResult r) {
    final key = r.indexKey;
    if (_pinned.add(key)) cache.pin(key);
    final file = ready(key, r).then<File?>((f) => f, onError: (Object e, StackTrace st) {
      AppLog.w('jam: download of $key failed', e, st);
      return null;
    });
    _tail = _tail.then((_) async {
      JamError? err;
      try {
        final f = await file;
        final ext = f == null ? '' : p.extension(f.path).replaceFirst('.', '').toLowerCase();
        err = f == null || _disposed || !jamExts.contains(ext)
            ? JamError.invalid
            : await send(JamCommand.add(JamItem(
                id: 0,
                ownerDeviceId: ownId,
                title: r.title,
                artist: displayArtist(r),
                album: r.album,
                durationMs: r.duration?.inMilliseconds ?? 0,
                ext: ext,
                sizeBytes: await f.length(),
                ref: 'yt:$key',
                videoId: r.id,
              )));
      } on Object catch (e, st) {
        // A failed step must not poison the chain: later adds still go out.
        AppLog.w('jam: add of $key failed', e, st);
        err = JamError.invalid;
      }
      if (err != null) {
        _release(key);
        if (!_disposed) onFailed(r);
      }
    });
  }

  /// Our items now in the shared queue: the Jam's own pins hold their keys from here on.
  void seen(Iterable<JamItem> queued) {
    final keys = {
      for (final i in queued)
        if (i.ownerDeviceId == ownId && i.ref?.startsWith('yt:') == true) i.ref!.substring(3),
    };
    _pinned.intersection(keys).toList().forEach(_release);
  }

  void dispose() {
    _disposed = true;
    _pinned.toList().forEach(_release);
  }

  void _release(String key) {
    if (_pinned.remove(key)) cache.unpin(key);
  }
}

/// The online items the output must download itself because their owner is gone:
/// the current and the next one only (K-07), never the whole queue. Only an output
/// downloads; keys in [failed] already failed this session and are not retried.
List<JamItem> jamSelfFetchTargets(JamState s, String ownId, {Set<String> failed = const {}}) {
  if (!s.outputs.contains(ownId)) return const [];
  final next = s.currentIndex + 1;
  return [
    for (final i in [s.current, if (next > 0 && next < s.items.length) s.items[next]])
      if (i != null && i.ownerDeviceId != ownId && i.selfFetchable &&
          (s.participant(i.ownerDeviceId)?.remote ?? true) && !failed.contains(i.ref!.substring(3)))
        i,
  ];
}

/// Downloads [item] from its YouTube id into our own cache through [ready]
/// (R-21). Null when it fails. shortcut: YouTube only, a SoundCloud row has no page address to rebuild.
Future<File?> jamFetchByVideoId(
    JamItem item, Future<File> Function(String key, YtResult r) ready) async {
  final key = item.ref!.substring('yt:'.length);
  try {
    return await ready(
        key,
        YtResult(
            id: item.videoId!,
            title: item.title,
            channel: item.artist ?? '',
            artists: [if (item.artist != null) item.artist!],
            album: item.album,
            duration: Duration(milliseconds: item.durationMs)));
  } on Object catch (e, st) {
    AppLog.w('jam: own download of $key failed', e, st);
    return null;
  }
}
