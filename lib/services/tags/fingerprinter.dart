import 'package:metadata_god/metadata_god.dart' as rust;

import '../../core/app_log.dart';
import 'metadata_god_init.dart';

/// Chromaprint of a file: `fp` as `fpcalc` prints it, `secs` the whole duration.
abstract class Fingerprinter {
  Future<({String fp, int secs})?> of(String path);
}

class RustFingerprinter implements Fingerprinter {
  @override
  Future<({String fp, int secs})?> of(String path) async {
    final p = path.toLowerCase();
    // The decoder cannot read them (R-184): do not even ask Rust.
    if (p.endsWith('.opus') || p.endsWith('.webm')) return null;
    try {
      await ensureMetadataGod();
      final f = await rust.fingerprint(path: path);
      return (fp: f.fingerprint, secs: f.durationS);
    } catch (e, st) {
      AppLog.w('fingerprint failed: $path', e, st);
      return null;
    }
  }
}
