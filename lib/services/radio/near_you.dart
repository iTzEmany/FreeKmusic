import 'radio_station.dart';
import 'regions.dart';
import '../../core/artist_key.dart';

/// True when [station]'s hand-typed `state` names [region] (or one of its
/// provincial capitals) as whole words, ignoring case, accents and punctuation.
bool matchesRegion(RadioStation station, RadioRegion region) {
  final k = matchKey(station.state);
  if (k.isEmpty) return false;
  final key = ' $k ';
  for (final n in [...region.names, ...region.cities]) {
    final nk = matchKey(n);
    if (nk.isNotEmpty && key.contains(' $nk ')) return true;
  }
  return false;
}

/// One entry per station name (by [matchKey]), in the order of first
/// appearance: the same station is often registered several times with
/// different addresses. The best copy stays: last check ok, then https, then
/// more clicks.
List<RadioStation> dedupe(List<RadioStation> stations) {
  final best = <String, RadioStation>{};
  for (final s in stations) {
    final key = matchKey(s.name);
    // A name without letters says nothing: keep such entries apart.
    final k = key.isEmpty ? 'id:${s.id}' : key;
    final old = best[k];
    if (old == null || _better(s, old)) best[k] = s;
  }
  return best.values.toList();
}

bool _better(RadioStation a, RadioStation b) {
  if (a.lastCheckOk != b.lastCheckOk) return a.lastCheckOk;
  if (a.isHttps != b.isHttps) return a.isHttps;
  return a.clickCount > b.clickCount;
}

/// The stations of [region], without repeats, the most listened first.
List<RadioStation> nearYou(List<RadioStation> stations, RadioRegion region) =>
    byClicks(dedupe([for (final s in stations) if (matchesRegion(s, region)) s]));

/// Most listened first; equal counts keep their order.
List<RadioStation> byClicks(List<RadioStation> stations) {
  final indexed = [for (var i = 0; i < stations.length; i++) (i, stations[i])];
  indexed.sort((a, b) {
    final c = b.$2.clickCount.compareTo(a.$2.clickCount);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
