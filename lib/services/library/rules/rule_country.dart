
import '../../../data/db/app_database.dart';
import '../../../data/repositories/artist_info_repository.dart';
import 'rule_ast.dart';

/// Country codes (upper case) a rule asks for with `nazionalita`.
Set<String> countriesOf(RuleExpr e) => switch (e) {
      RuleAnd(:final terms) => {for (final t in terms) ...countriesOf(t)},
      RuleOr(:final left, :final right) => {...countriesOf(left), ...countriesOf(right)},
      RuleNot(:final inner) => countriesOf(inner),
      RuleContains(:final field, :final value) when field == RuleField.country => {value.toUpperCase()},
      RuleIn(:final field, :final values) when field == RuleField.country => {
          for (final v in values) v.toUpperCase(),
        },
      _ => const {},
    };

/// For each country the rule mentions, the `tracks.artist` spellings whose main
/// artist (`ArtistInfoRepository.keyOf`) is stored in `artist_countries` with
/// that country. The key is a Dart normalisation SQL cannot reproduce, so it is
/// resolved here over the distinct artists of the library (not per track).
/// Pass the result to `toSql(countryArtists:)`.
Future<Map<String, List<String>>> countryArtistsOf(AppDatabase db, RuleExpr e) async {
  final wanted = countriesOf(e);
  if (wanted.isEmpty) return const {};
  final byKey = <String, String>{};
  for (final r in await db.customSelect('SELECT artist_key AS k, upper(country) AS c FROM artist_countries WHERE country IS NOT NULL').get()) {
    final c = r.read<String>('c');
    if (wanted.contains(c)) byKey[r.read<String>('k')] = c;
  }
  final out = {for (final c in wanted) c: <String>[]};
  if (byKey.isEmpty) return out;
  final artists = await db.customSelect(
    "SELECT DISTINCT artist FROM tracks WHERE artist IS NOT NULL AND artist <> ''",
    readsFrom: {db.tracks},
  ).get();
  for (final r in artists) {
    final a = r.read<String>('artist');
    final c = byKey[ArtistInfoRepository.keyOf(a)];
    if (c != null) out[c]!.add(a);
  }
  return out;
}

/// The fields a rule reads, to know which tables it depends on.
Set<RuleField> fieldsOf(RuleExpr e) => switch (e) {
      RuleAnd(:final terms) => {for (final t in terms) ...fieldsOf(t)},
      RuleOr(:final left, :final right) => {...fieldsOf(left), ...fieldsOf(right)},
      RuleNot(:final inner) => fieldsOf(inner),
      RuleContains(:final field) || RuleIn(:final field) || RuleNumber(:final field) => {field},
      _ => const {},
    };
