import 'dart:isolate';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_log.dart';
import '../../data/repositories/track_repository.dart';
import 'mp3_length.dart';

/// One entry per path: null = not measurable, [failed] = the file could not be opened or read.
typedef Mp3Measure = ({int ms, int bps, bool failed})?;
typedef Mp3Lengths = Future<List<Mp3Measure>> Function(List<String> paths);

Future<List<Mp3Measure>> _measureInIsolate(List<String> paths) => Isolate.run(() => [
      for (final p in paths) _one(p),
    ]);

Mp3Measure _one(String path) {
  try {
    final m = mp3LengthChecked(path);
    return m == null ? null : (ms: m.ms, bps: m.bps, failed: false);
  } on Object catch (e, st) {
    AppLog.w('mp3 length: cannot read $path', e, st);
    return (ms: 0, bps: 0, failed: true);
  }
}

/// One-off: the mp3 rows read before the length of Info / header-less files was right get the
/// real length and bitrate. Nothing else is read back, so corrected titles and artists stay.
class Mp3LengthFix {
  Mp3LengthFix(this._tracks, this._prefs, {Mp3Lengths? measure}) : _measure = measure ?? _measureInIsolate;

  static const flag = 'mp3DurationFix1';
  static const _group = 50;

  final TrackRepository _tracks;
  final SharedPreferences _prefs;
  final Mp3Lengths _measure;
  static bool _running = false; // one pass at a time, whoever asks

  /// Rows changed (0 when it already ran or is running).
  Future<int> runOnce() async {
    if (_running || _prefs.getBool(flag) == true) return 0;
    _running = true;
    try {
      final rows = await _tracks.mp3LengthRows();
      var changed = 0, failed = 0;
      for (var i = 0; i < rows.length; i += _group) {
        final chunk = rows.skip(i).take(_group).toList();
        final out = await _measure([for (final r in chunk) r.path]);
        final fixes = <({int id, int durationMs, int bitrateKbps})>[];
        for (var k = 0; k < chunk.length; k++) {
          final m = out[k];
          if (m == null) continue;
          if (m.failed) {
            failed++;
            continue;
          }
          final kbps = m.bps ~/ 1000;
          // The bitrate too: a VBR file with Xing had the right length and the Xing frame's bitrate.
          if ((m.ms - chunk[k].durationMs).abs() > 1000 || (kbps - (chunk[k].bitrateKbps ?? 0)).abs() > 2) {
            fixes.add((id: chunk[k].id, durationMs: m.ms, bitrateKbps: kbps));
          }
        }
        if (fixes.isEmpty) continue;
        await _tracks.setLengths(fixes);
        changed += fixes.length;
      }
      // A file that could not be read is tried again at the next start.
      if (failed == 0) await _prefs.setBool(flag, true);
      AppLog.i('mp3 length fix: $changed of ${rows.length} rows, $failed unreadable');
      return changed;
    } on Object catch (e, st) {
      AppLog.w('mp3 length fix failed, will retry next start', e, st);
      return 0;
    } finally {
      _running = false;
    }
  }
}
