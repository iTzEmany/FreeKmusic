/// `tracks.kind` values. Library views filter `kind = 0`; history and stats
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
