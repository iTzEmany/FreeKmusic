import '../../core/text_utils.dart';
import '../../data/db/app_database.dart' show Track;
import '../online/query_cleaner.dart';

/// YouTube uploaders seen as «artist» in downloaded files that no rule below
/// can tell from a real artist. Exact names (K-RB-07), not patterns.
const kKnownChannels = <String>{
  '7clouds Rock', 'Trap City', 'The Vibe Guide', 'RHINO', 'retrovgnamusic', 'Pokeli',
  'Nintendo Soundtracks', 'Nullfuchs', 'Unique Sound', 'U/M/A/A Inc.',
  'TVアニメ【推しの子】公式チャンネル', 'Sideaccount', 'Shai Ming', 'RadiatorRampardos',
  'pokemonmusicmaster', 'Nerial - Creator of Card Shark & Reigns', 'Leta Sharonda',
  'KobiVISUAL', 'KAMACHI PEACH', 'KaizenK', 'Jamong', 'harry jagger', 'DyCherii',
  'DeathPok3r', 'Daniel Mullins Games', 'Crunchyroll Collection', '‡cherryred‡',
  'Ben Booze', 'Baumy L3viさくら天使', 'Angie恩熙',
};

final _known = {for (final c in kKnownChannels) normalize(c)};
const _channelWords = {'records', 'music', 'lyrics', 'lyric'};

/// «Atlantic Records», «Sony Music», «Lyrics»-channels: the word ends the name
/// and something other than «The» comes before it («The Music» is a band).
/// shortcut: a real «Roxy Music» counts as dubious, which only sends it to AcoustID first.
bool _channelByWord(String normalized) {
  final w = normalized.split(' ');
  if (w.length < 2 || !_channelWords.contains(w.last)) return false;
  return !(w.length == 2 && w.first == 'the');
}

/// The artist tag names a channel or nobody (empty, generic, known, «… Records»).
bool artistIsChannel(String artist) {
  final a = artist.trim();
  final n = normalize(a);
  return isGenericArtist(a) || _known.contains(n) || _channelByWord(n);
}

/// R-163: the tags probably do not name the song's real artist (empty or
/// generic, a channel, or «Other Artist - Title» in the title).
bool tagsDubious(Track t) {
  final artist = (t.artist ?? '').trim();
  return artistIsChannel(artist) || cleanSearchQuery(t.title, artist).tagged != null;
}
