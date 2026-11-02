import 'dart:isolate';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_log.dart';
import '../../data/repositories/track_repository.dart';
import 'mp3_length.dart';

typedef Mp3Lengths = Future<List<({int ms, int bps})?>> Function(List<String> paths);

Future<List<({int ms, int bps})?>> _measureInIsolate(List<String> paths) =>
    Isolate.run(() => [for (final p in paths) mp3Length(p)]);

/// One-off: the mp3 rows read before the length of Info / header-less files was right get the
/// real length and bitrate. Nothing else is read back, so corrected titles and artists stay.
class Mp3LengthFix {
  Mp3LengthFix(this._tracks, this._prefs, {Mp3Lengths? measure}) : _measure = measure ?? _measureInIsolate;

  static const flag = 'mp3DurationFix1';
  static const _group = 50;

  final TrackRepository _tracks;
  final SharedPreferences _prefs;
  final Mp3Lengths _measure;
  bool _running = false;

  /// Rows changed (0 when it already ran or is running).
  Future<int> runOnce() async {
    if (_running || _prefs.getBool(flag) == true) return 0;
    _running = true;
    try {
      final rows = await _tracks.mp3LengthRows();
      var changed = 0;
      for (var i = 0; i < rows.length; i += _group) {
        final chunk = rows.skip(i).take(_group).toList();
        final out = await _measure([for (final r in chunk) r.path]);
        final fixes = <({int id, int durationMs, int bitrateKbps})>[];
        for (var k = 0; k < chunk.length; k++) {
          final m = out[k];
          if (m == null) continue;
          if ((m.ms - chunk[k].durationMs).abs() > 1000) {
            fixes.add((id: chunk[k].id, durationMs: m.ms, bitrateKbps: m.bps ~/ 1000));
          }
        }
        if (fixes.isEmpty) continue;
        await _tracks.setLengths(fixes);
        changed += fixes.length;
      }
      await _prefs.setBool(flag, true);
      AppLog.i('mp3 length fix: $changed of ${rows.length} rows');
      return changed;
    } on Object catch (e, st) {
      AppLog.w('mp3 length fix failed, will retry next start', e, st);
      return 0;
    } finally {
      _running = false;
    }
  }
}
