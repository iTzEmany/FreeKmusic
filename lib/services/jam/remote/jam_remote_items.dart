import '../../../core/app_log.dart';
import '../../../data/db/app_database.dart';
import '../jam_models.dart';

/// Library tracks of a remote guest as `yt:` items (R-152, D-240): only the video id
/// goes over the bridge, the host downloads or streams it itself.
class JamRemoteItems {
  /// [resolve]: the video id of a track, null when not found (`SeedResolver.resolve`).
  JamRemoteItems(this.resolve);

  final Future<String?> Function(Track track) resolve;

  /// Null when the track is not found online. A network error counts as not found, unless
  /// [rethrowErrors]: the feeder retries those instead of giving the track up.
  Future<JamItem?> of(
    Track t,
    String ownId, {
    String? partKey,
    bool suggested = false,
    bool rethrowErrors = false,
  }) async {
    final String? vid;
    try {
      vid = await resolve(t);
    } on Object catch (e, st) {
      if (rethrowErrors) rethrow;
      AppLog.w('jam: could not look up "${t.title}" online', e, st);
      return null;
    }
    if (vid == null) return null;
    return JamItem(
      id: 0,
      ownerDeviceId: ownId,
      title: t.title,
      artist: t.artist,
      album: t.album,
      durationMs: t.durationMs,
      ext: 'webm', // by convention: whoever downloads uses the extension of its own file
      sizeBytes: 0,
      ref: 'yt:youtube:$vid',
      videoId: vid,
      suggested: suggested,
      partKey: partKey,
    );
  }
}
