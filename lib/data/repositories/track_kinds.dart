import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// `tracks.kind` values. Library views filter [libraryRowSql] (files, and saved streams); history and stats
/// use [listenKinds]; a shadow row (a streamed track cached for playback) is
/// never shown in the library.
const kMusicKind = 0;
const kEpisodeKind = 1;
const kStreamKind = 2;
const listenKinds = [kMusicKind, kStreamKind];

/// An episode row (kind 1) with no file yet plays as a stream: its path is the
/// audio address (`http(s)://`), or `stream:<key>` for a YouTube Music one.
/// Downloading it later rewrites the path to the local file.
bool isRemoteEpisodePath(String path) =>
    isHttpAddress(path) || path.startsWith('stream:');

/// An `http://` or `https://` address, in any letter case (as `Uri.scheme` reads it).
bool isHttpAddress(String s) =>
    RegExp(r'^https?://', caseSensitive: false).hasMatch(s);

/// A row the library shows: a file on the device, or a streamed track the user saved (D-607).
/// [alias] is the table alias in the query, when it has one.
String libraryRowSql([String? alias, LibraryFilter filter = LibraryFilter.all]) {
  final a = alias == null ? '' : '$alias.';
  final device = '${a}kind = $kMusicKind';
  final stream = '(${a}kind = $kStreamKind AND ${a}saved = 1)';
  return switch (filter) {
    LibraryFilter.all => '($device OR $stream)',
    LibraryFilter.device => '($device)',
    LibraryFilter.stream => stream,
  };
}

/// The filter on top of Brani, Album and Artisti (D-596): every library row, only the files, only the saved streams.
enum LibraryFilter { all, device, stream }

/// [libraryRowSql] on a loaded row.
bool isLibraryTrack(Track t) => t.kind == kMusicKind || (t.kind == kStreamKind && t.saved);

/// The drift form of [libraryRowSql].
Expression<bool> isLibraryRow($TracksTable t, [LibraryFilter filter = LibraryFilter.all]) {
  final device = t.kind.equals(kMusicKind);
  final stream = t.kind.equals(kStreamKind) & t.saved.equals(true);
  return switch (filter) {
    LibraryFilter.all => device | stream,
    LibraryFilter.device => device,
    LibraryFilter.stream => stream,
  };
}
