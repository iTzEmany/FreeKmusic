/// The 12 macro-genres of the Top 20 grid (D-591).
class ChartGenre {
  const ChartGenre(
    this.id,
    this.deezer,
    this.appleGenreIds, {
    this.fallbackDeezer,
    this.fixedCountry,
  });

  /// Stable key, also used in the cache key `chart:<id>:<country>`.
  final String id;

  /// Deezer chart id; null when Deezer has no chart (Italiana: Apple feed only).
  final int? deezer;

  /// Tried when [deezer] answers empty.
  final int? fallbackDeezer;

  /// Apple `genres[].genreId` accepted by the filter. Ids, not names: Apple
  /// localizes the names by country («Latina», «Alternativa»).
  final List<String> appleGenreIds;

  /// The whole feed of this country, whatever the user's country.
  final String? fixedCountry;
}

const chartGenres = <ChartGenre>[
  ChartGenre('pop', 132, ['14']),
  ChartGenre('rap', 116, ['18']), // Hip-Hop/Rap
  ChartGenre('rock', 152, ['21']),
  ChartGenre('dance', 113, ['17', '7'], fallbackDeezer: 106), // Dance, Electronic
  ChartGenre('rnb', 165, ['15'], fallbackDeezer: 169), // R&B/Soul
  ChartGenre('latin', 197, ['12'], fallbackDeezer: 122),
  ChartGenre('italian', null, [], fixedCountry: 'it'),
  ChartGenre('indie', 85, ['20']), // Alternative
  ChartGenre('jazz', 129, ['2']),
  ChartGenre('classical', 98, ['5']),
  ChartGenre('metal', 464, ['1153', '1152']), // Metal, Hard Rock
  ChartGenre('country', 84, ['6']),
];
