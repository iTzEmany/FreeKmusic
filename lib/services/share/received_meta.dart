import 'dart:typed_data';

import '../../core/app_log.dart';
import '../../data/repositories/credits_repository.dart';
import '../../data/repositories/track_repository.dart';
import '../covers/cover_store.dart';
import '../online/youtube_service.dart' show YtResult;
import '../stream/stream_key.dart' show streamResultOf;
import 'offers.dart' show StreamOffer;
import 'track_meta.dart';

typedef ReceivedCover = ({Uint8List bytes, String mime});

/// Gives a freshly scanned received file the sender's metadata and cover.
/// Never throws: a failure is logged and the file stays as the scan made it.
Future<void> applyReceivedPackage(
  TrackRepository tracks,
  CoverStore covers,
  String path,
  TrackMeta? meta, {
  Future<ReceivedCover?> Function()? fetchCover,
  CreditsRepository? credits,
}) async {
  try {
    final row = await tracks.byPath(path);
    if (row == null) {
      AppLog.w('received file not in library: $path');
      return;
    }
    final albumKey = meta == null
        ? row.albumKey
        : await tracks.applyReceivedMeta(row.id, meta) ?? row.albumKey;
    if (meta != null && credits != null) await credits.saveIfNone(row.id, meta.credits, meta.details);
    final cover = fetchCover == null ? null : await fetchCover();
    if (cover == null) return;
    final key = await covers.saveFromBytes(albumKey, cover.bytes, cover.mime);
    if (key != null) await tracks.setCoverForAlbum(albumKey, true, key);
  } on Object catch (e, st) {
    AppLog.w('received metadata not applied: $path', e, st);
  }
}

/// Saves each offered stream as a «saved in streaming» row (D-674), skipping the ones
/// [hasFile] says are already on the device. Returns how many were saved. Never throws.
Future<int> saveReceivedStreams(
  TrackRepository tracks,
  List<StreamOffer> streams, {
  required bool Function(YtResult) hasFile,
  CreditsRepository? credits,
}) async {
  var n = 0;
  for (final s in streams) {
    try {
      final r = streamResultOf(s.key, title: s.title, artist: s.artist, album: s.album, durationMs: s.durationMs);
      if (hasFile(r)) continue;
      final wasSaved = (await tracks.streamRow(s.key))?.saved ?? false;
      final id = await tracks.saveStream(r);
      if (id == null) continue;
      if (!wasSaved) n++;
      final m = s.meta;
      if (m != null && credits != null) await credits.saveIfNone(id, m.credits, m.details);
    } on Object catch (e, st) {
      AppLog.w('received stream not saved: ${s.key}', e, st);
    }
  }
  return n;
}
