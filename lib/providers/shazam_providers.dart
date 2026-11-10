import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../core/artist_key.dart' show matchKey;
import '../data/db/app_database.dart' show Track;
import '../services/import/track_matcher.dart' show libraryTitleKey;
import '../services/online/external_collection.dart' show ExternalTrack, TrackNotFound, TrackReady, TrackReadyLibrary, TrackReadyOnline;
import '../services/online/shared_text.dart' show ShazamShare;
import '../services/online/youtube_service.dart' show YtResult;
import '../services/stream/stream_key.dart' show displayArtist;
import 'database_providers.dart';
import 'settings_providers.dart';
import 'smart_search_providers.dart' show collectionMatcherProvider;
import 'youtube_providers.dart' show downloadsProvider;

/// Name of the playlist; shortcut: not localised (a proper name, like the app's), created once.
const kShazamPlaylistName = 'Da Shazam';

/// What [ShazamInbox.add] did; the shell turns it into a snackbar.
sealed class ShazamResult {
  const ShazamResult();
}

/// Put at the top of «Da Shazam»; [online] is set when it streams (for «Ascolta»).
class ShazamAdded extends ShazamResult {
  const ShazamAdded(this.title, {this.online, this.track});
  final String title;
  final YtResult? online;
  final Track? track;
}

class ShazamDuplicate extends ShazamResult {
  const ShazamDuplicate(this.title);
  final String title;
}

class ShazamNotFound extends ShazamResult {
  const ShazamNotFound();
}

/// Offline or a passing failure: nothing was changed, «Riprova» asks again.
class ShazamRetry extends ShazamResult {
  const ShazamRetry();
}

class ShazamInbox {
  ShazamInbox(this._ref);
  final Ref _ref;

  Future<ShazamResult> add(ShazamShare s) async {
    final track = ExternalTrack(title: s.title, artists: [s.artist], key: s.shazamUrl ?? s.title);
    // autoDispose family: held while the match runs; a fresh key so a quick retry never meets a cancelled matcher.
    final sub = _ref.listen(collectionMatcherProvider(Object()), (_, _) {});
    try {
      final (_, m) = await sub.read().match([track]).first;
      return switch (m) {
        TrackReady() => await _put(m),
        TrackNotFound(:final transient) => transient ? const ShazamRetry() : const ShazamNotFound(),
        _ => const ShazamRetry(),
      };
    } on Object catch (e, st) {
      AppLog.w('shazam: add failed', e, st);
      return const ShazamRetry();
    } finally {
      sub.close();
    }
  }

  /// The writes of two overlapping adds run one after the other: otherwise both
  /// would create the playlist, or both miss the other's row.
  Future<void> _tail = Future.value();

  Future<ShazamResult> _put(TrackReady m) {
    final run = _tail.then((_) => _write(m));
    _tail = run.then((_) {}, onError: (Object _) {}); // an error never poisons the chain
    return run;
  }

  Future<ShazamResult> _write(TrackReady m) async {
    final tracks = _ref.read(trackRepositoryProvider);
    final playlists = _ref.read(playlistRepositoryProvider);
    final store = _ref.read(settingsStoreProvider);
    final (title, artist, online, lib) = switch (m) {
      TrackReadyLibrary(:final track) => (track.title, track.artist ?? '', null, track),
      TrackReadyOnline(:final result) => (result.title, displayArtist(result), result, null),
    };
    final uuid = store.readShazamPlaylistUuid();
    var pid = uuid == null ? null : await playlists.idByUuid(uuid);
    if (pid == null) {
      pid = await playlists.create(kShazamPlaylistName);
      await store.writeShazamPlaylistUuid((await playlists.uuidOf(pid))!);
    }
    final key = '${libraryTitleKey(title)}|${matchKey(artist)}';
    final rows = await playlists.watchTracks(pid).first;
    // Before ensureStreamRow: a duplicate leaves no unused shadow row.
    if (rows.any((t) => '${libraryTitleKey(t.title)}|${matchKey(t.artist ?? '')}' == key)) {
      return ShazamDuplicate(title);
    }
    final id = lib?.id ?? await tracks.ensureStreamRow(online!);
    if (!await playlists.addAtTop(pid, id)) return ShazamDuplicate(title); // same id
    if (online != null && store.readShazamAutoDownload()) {
      await _ref.read(downloadsProvider.notifier).add(online).catchError((Object e, StackTrace st) {
        AppLog.w('shazam: download not started', e, st);
        return false;
      });
    }
    return ShazamAdded(title, online: online, track: lib);
  }
}

final shazamInboxProvider = Provider<ShazamInbox>(ShazamInbox.new);
