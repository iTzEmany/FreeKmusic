import 'dart:convert';
import 'dart:io';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart' show Track;
import '../online/search_cache.dart' show ytResultFromJson, ytResultToJson;
import '../online/ytm_radio_parser.dart' show RadioKind;
import '../shuffle_plus/suggestion_pool.dart' show SuggestionCandidate;
import 'daylist_builder.dart';

/// Name of the saved daylist in the data folder.
const daylistFileName = 'daylist.json';

/// The daylist of the current slot on disk (D-474): reopening the app in the
/// same slot gives the same one, without computing it or asking the network.
/// [key] says what it was made with (slots and mood table), [until] is when
/// its slot ends; anything else means the saved one is stale.
class DaylistStore {
  DaylistStore(this.file);

  final Future<File> Function() file;

  /// Not saved: a [DaylistResult.tooFew] one (it is cheap to work out again).
  Future<void> save({
    required String key,
    required DateTime until,
    required DaylistResult result,
  }) async {
    final json = jsonEncode({
      'key': key,
      'until': until.millisecondsSinceEpoch,
      'slot': result.slotIndex,
      'genres': result.genres,
      'items': [
        for (final i in result.items)
          if (i.track != null)
            {'t': i.track!.id}
          else
            {
              'r': ytResultToJson(i.suggestion!.result),
              's': i.suggestion!.seedTitle,
              'k': i.suggestion!.kind.index,
            },
      ],
    });
    try {
      final f = await file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(f.path);
    } on IOException catch (e, st) {
      AppLog.w('daylist not saved', e, st);
    }
  }

  /// The saved daylist when it was made with [key] and ends at [until]; null
  /// when there is none, it is stale or unreadable, or too many of its songs
  /// are gone from the library. [tracksOf] reads library songs by id (in order).
  Future<DaylistResult?> load({
    required String key,
    required DateTime until,
    required Future<List<Track>> Function(List<int> ids) tracksOf,
  }) async {
    try {
      final f = await file();
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString());
      if (j is! Map ||
          j['key'] != key ||
          j['until'] != until.millisecondsSinceEpoch) {
        return null;
      }
      final slot = j['slot'], rawItems = j['items'];
      if (slot is! int || rawItems is! List) {
        throw const FormatException('bad daylist file');
      }
      final ids = [
        for (final i in rawItems)
          if (i is Map && i['t'] is int) i['t'] as int,
      ];
      final byId = {
        for (final t in await tracksOf(ids))
          if (t.kind == 0 && !t.missing && !t.ignored) t.id: t,
      };
      final items = <DaylistItem>[];
      for (final i in rawItems) {
        if (i is! Map) continue;
        final track = i['t'] is int ? byId[i['t']] : null;
        final r = ytResultFromJson(i['r']);
        if (track != null) {
          items.add(DaylistItem.own(track));
        } else if (r != null &&
            i['s'] is String &&
            i['k'] is int &&
            i['k'] >= 0 &&
            i['k'] < RadioKind.values.length) {
          items.add(
            DaylistItem.suggested(
              SuggestionCandidate(
                r,
                i['s'] as String,
                RadioKind.values[i['k'] as int],
              ),
            ),
          );
        }
      }
      if (items.length < DaylistBuilder.minTracks) return null;
      return DaylistResult(
        slotIndex: slot,
        items: items,
        genres: [
          for (final g
              in (j['genres'] is List ? j['genres'] as List : const []))
            '$g',
        ],
        tooFew: false,
      );
    } on Object catch (e, st) {
      AppLog.w('daylist file unreadable, made again', e, st);
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final f = await file();
      if (await f.exists()) await f.delete();
    } on IOException catch (e, st) {
      AppLog.w('daylist file not removed', e, st);
    }
  }
}
