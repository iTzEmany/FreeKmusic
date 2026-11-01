import 'package:metadata_god/metadata_god.dart' as rust;

import '../../core/app_log.dart';
import 'metadata_god_init.dart';

/// Chromaprint of a file: `fp` as `fpcalc` prints it, `secs` the whole duration.
abstract class Fingerprinter {
  /// Opus and WebM cannot be decoded (R-184): they are never fingerprinted.
  static bool supports(String path) {
    final p = path.toLowerCase();
    return !p.endsWith('.opus') && !p.endsWith('.webm');
  }

  Future<({String fp, int secs})?> of(String path);
}

class RustFingerprinter implements Fingerprinter {
  @override
  Future<({String fp, int secs})?> of(String path) async {
    // Do not even ask Rust.
    if (!Fingerprinter.supports(path)) return null;
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
