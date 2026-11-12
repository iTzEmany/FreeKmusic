import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_log.dart';
import '../../core/text_utils.dart';
import '../../data/repositories/track_repository.dart';
import '../covers/cover_store.dart';
import 'library_scanner.dart';

/// One-off: downloads once shared the cover of their «unknown|dir» key and kept it after
/// getting a real album. Each such row takes the cover of its own album, or none. Hand-picked
/// covers (cover_source > 0) are never touched.
class SharedCoverFix {
  SharedCoverFix(this._tracks, this._scanner, this._prefs);

  static const flag = 'sharedUnknownCoverFix1';

  final TrackRepository _tracks;
  final LibraryScanner _scanner;
  final SharedPreferences _prefs;
  static bool _running = false;

  /// Rows changed (0 when it already ran or is running).
  Future<int> runOnce() async {
    if (_running || _prefs.getBool(flag) == true) return 0;
    _running = true;
    try {
      var changed = 0;
      for (final r in await _tracks.autoCoverRowsOfRealAlbums()) {
        final shared = CoverStore.coverKeyFor(
          computeAlbumKey(directory: p.dirname(r.path)),
        );
        if (r.coverKey != shared) continue;
        await _tracks.setAutoCover(r.id, await _scanner.originalCoverKey(r.albumKey, r.path));
        changed++;
      }
      await _prefs.setBool(flag, true);
      AppLog.i('shared cover fix: $changed rows');
      return changed;
    } on Object catch (e, st) {
      AppLog.w('shared cover fix failed, will retry next start', e, st);
      return 0;
    } finally {
      _running = false;
    }
  }
}
