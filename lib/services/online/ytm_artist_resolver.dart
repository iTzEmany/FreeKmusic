import '../../data/repositories/artist_alias_repository.dart' show ArtistAliasRepository;
import '../import/track_matcher.dart' show matchKey;
import 'query_cleaner.dart' show extractPrimaryArtist;
import 'ytm_artist.dart';

/// How many artists the choice sheet offers.
const _choices = 3;

/// What to do with the artists YouTube Music found for a library artist.
sealed class YtmArtistPick {
  const YtmArtistPick();
}

/// One single artist has that name: open it.
class ExactArtist extends YtmArtistPick {
  const ExactArtist(this.artist);

  final YtmArtistRef artist;
}

/// None is certain: let the user choose among the first few.
class ChooseArtist extends YtmArtistPick {
  const ChooseArtist(this.artists);

  final List<YtmArtistRef> artists;
}

/// YouTube Music found nobody.
class NoArtist extends YtmArtistPick {
  const NoArtist();
}

/// The normalized forms a name is compared by: whole, and without «feat.» (never empty).
Set<String> artistNameKeys(String name) =>
    {matchKey(name), matchKey(extractPrimaryArtist(name))}..remove('');

/// [pickYtmArtist] with the merged artists of [repo]: the one place that applies aliases.
Future<YtmArtistPick> pickYtmArtistWithAliases(
        ArtistAliasRepository? repo, String localName, List<YtmArtistRef> found) async =>
    pickYtmArtist(localName, found, aliases: await repo?.allAliases() ?? const {});

/// Opens an artist by itself only when exactly one of [found] has the name of
/// [localName] (case, accents and «feat.» ignored); otherwise the first three
/// are offered, and nothing when [found] is empty. [aliases] (alias id -> main id):
/// when the same-name profiles are one artist's group, its main profile opens.
YtmArtistPick pickYtmArtist(String localName, List<YtmArtistRef> found, {Map<String, String> aliases = const {}}) {
  if (found.isEmpty) return const NoArtist();
  final keys = artistNameKeys(localName);
  final same = [for (final a in found) if (keys.contains(matchKey(a.name))) a];
  if (same.length == 1) return ExactArtist(same.single);
  if (same.length > 1) {
    final mains = {for (final a in same) aliases[a.id] ?? a.id};
    if (mains.length == 1) {
      // The page of any member redirects to the main profile.
      return ExactArtist(same.firstWhere((a) => a.id == mains.single, orElse: () => same.first));
    }
  }
  return ChooseArtist(found.take(_choices).toList());
}
